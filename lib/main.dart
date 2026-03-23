import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
  home: MainNavigation(),
));

class MainNavigation extends StatefulWidget {
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<Widget> _pages = [LaoMaSearchPage(), LaoMaUserPage()];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _currentIndex, children: _pages),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (i) => setState(() => _currentIndex = i),
      destinations: const [NavigationDestination(icon: Icon(Icons.search), label: '搜书'), NavigationDestination(icon: Icon(Icons.person), label: '我的')],
    ),
  );
}

class LaoMaSearchPage extends StatefulWidget {
  @override
  _LaoMaSearchPageState createState() => _LaoMaSearchPageState();
}

class _LaoMaSearchPageState extends State<LaoMaSearchPage> {
  final TextEditingController _input = TextEditingController();
  List<Map<String, String>> _results = [];
  List<String> _suggestions = [];
  bool _isLoading = false;

  // 联想词：用来证明 App 到底能不能上网
  Future<void> _getSuggestions(String q) async {
    if (q.isEmpty) { setState(() => _suggestions = []); return; }
    try {
      final res = await Dio().get("https://suggestion.baidu.com/5a?wd=$q");
      String data = res.data.toString();
      if (data.contains("s:[")) {
        String s = data.split("s:[")[1].split("]")[0];
        List<String> list = s.split(",").map((e) => e.replaceAll('"', '')).toList();
        setState(() => _suggestions = list.take(5).toList());
      }
    } catch (e) { print("联网失败: $e"); }
  }

  Future<void> _search(String key) async {
    if (key.isEmpty) return;
    setState(() { _isLoading = true; _results = []; _suggestions = []; });
    final prefs = await SharedPreferences.getInstance();
    List<String> sources = prefs.getStringList('all_sources') ?? ['ting78.com', 'shuyinfm.com', 'huanting.cc', 'tingsm.com'];
    List<String> disabled = prefs.getStringList('disabled_sources') ?? [];
    List<String> active = sources.where((s) => !disabled.contains(s)).toList();
    try {
      String siteQuery = active.isEmpty ? "" : active.map((s) => "site:$s").join(" OR ");
      final res = await Dio(BaseOptions(connectTimeout: Duration(seconds: 8))).get("https://www.baidu.com/s?wd=$siteQuery $key", options: Options(headers: {'User-Agent': 'Mozilla/5.0'}));
      final doc = parse(res.data);
      final items = doc.querySelectorAll('div.result.c-container');
      setState(() => _results = items.map((e) => {'title': e.querySelector('h3.t > a')?.text ?? '听书源', 'url': e.querySelector('h3.t > a')?.attributes['href'] ?? ''}).where((m) => m['url']!.isNotEmpty).toList());
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("搜索失败，请检查网络或书源"))); }
    finally { setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('老马精准听书')),
    body: Column(children: [
      Padding(padding: EdgeInsets.all(15), child: Column(children: [
        TextField(controller: _input, onChanged: _getSuggestions, decoration: InputDecoration(hintText: "输入书名...", suffixIcon: IconButton(icon: Icon(Icons.send), onPressed: () => _search(_input.text))), onSubmitted: _search),
        if (_suggestions.isNotEmpty) Container(width: double.infinity, color: Colors.white, child: Column(children: _suggestions.map((s) => ListTile(title: Text(s, style: TextStyle(color: Colors.green)), dense: true, onTap: () { _input.text = s; _search(s); })).toList())),
      ])),
      Expanded(child: _isLoading ? Center(child: CircularProgressIndicator()) : ListView.builder(itemCount: _results.length, itemBuilder: (c, i) => ListTile(title: Text(_results[i]['title']!), trailing: Icon(Icons.play_circle), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => Scaffold(appBar: AppBar(title: Text("正在播放")), body: WebViewWidget(controller: WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..loadRequest(Uri.parse(_results[i]['url']!)))))))))
    ]),
  );
}

class LaoMaUserPage extends StatefulWidget {
  @override
  _LaoMaUserPageState createState() => _LaoMaUserPageState();
}

class _LaoMaUserPageState extends State<LaoMaUserPage> {
  List<String> _sources = [];
  List<String> _disabled = [];
  @override
  void initState() { super.initState(); _load(); }
  _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { _sources = prefs.getStringList('all_sources') ?? ['shuyinfm.com', 'huanting.cc', 'ting78.com', 'tingsm.com', 'ting74.org', 'ting27.com']; _disabled = prefs.getStringList('disabled_sources') ?? []; });
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text("个人中心")), body: ListView(children: [
    Padding(padding: EdgeInsets.all(16), child: Text("勾选开启书源")),
    ..._sources.map((s) => CheckboxListTile(title: Text(s), value: !_disabled.contains(s), onChanged: (v) async { setState(() { v! ? _disabled.remove(s) : _disabled.add(s); }); final prefs = await SharedPreferences.getInstance(); await prefs.setStringList('disabled_sources', _disabled); })),
    ListTile(title: Text("微信客服：q13978984"))
  ]));
}
