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
  final List<Widget> _pages = [LaoMaSearchPage(), LaoMaSettingsPage()];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _currentIndex, children: _pages),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (i) => setState(() => _currentIndex = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.search), label: '精准搜书'),
        NavigationDestination(icon: Icon(Icons.person), label: '个人中心'),
      ],
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
  bool _isLoading = false;

  // 搜索逻辑
  Future<void> _search(String key) async {
    if (key.isEmpty) return;
    setState(() { _isLoading = true; _results = []; FocusScope.of(context).unfocus(); });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> sources = prefs.getStringList('all_sources') ?? ['ting78.com', 'shuyinfm.com', 'huanting.cc'];
      List<String> disabled = prefs.getStringList('disabled_sources') ?? [];
      List<String> active = sources.where((s) => !disabled.contains(s)).toList();

      if (active.isEmpty) throw "请先在个人中心开启书源";

      String siteQuery = active.map((s) => "site:$s").join(" OR ");
      
      // 发起请求
      final res = await Dio(BaseOptions(connectTimeout: Duration(seconds: 10))).get(
        "https://www.baidu.com/s?wd=$siteQuery $key", 
        options: Options(headers: {'User-Agent': 'Mozilla/5.0'})
      );
      
      final doc = parse(res.data);
      final items = doc.querySelectorAll('div.result.c-container');
      
      setState(() {
        _results = items.map((e) => {
          'title': e.querySelector('h3.t > a')?.text ?? '听书资源',
          'url': e.querySelector('h3.t > a')?.attributes['href'] ?? '',
        }).where((m) => m['url']!.isNotEmpty).toList();
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("联网失败: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('老马精准听书·强力联网版')),
    body: Column(
      children: [
        Padding(
          padding: EdgeInsets.all(15),
          child: TextField(
            controller: _input,
            decoration: InputDecoration(
              hintText: "输入书名搜资源...",
              suffixIcon: IconButton(icon: Icon(Icons.send, color: Colors.green), onPressed: () => _search(_input.text)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onSubmitted: _search,
          ),
        ),
        Expanded(
          child: _isLoading ? Center(child: CircularProgressIndicator()) : ListView.builder(
            itemCount: _results.length,
            itemBuilder: (c, i) => ListTile(
              title: Text(_results[i]['title']!),
              trailing: Icon(Icons.play_circle),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => Scaffold(
                appBar: AppBar(title: Text("正在播放")),
                body: WebViewWidget(controller: WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..loadRequest(Uri.parse(_results[i]['url']!))),
              ))),
            ),
          ),
        ),
      ],
    ),
  );
}

class LaoMaSettingsPage extends StatefulWidget {
  @override
  _LaoMaSettingsPageState createState() => _LaoMaSettingsPageState();
}

class _LaoMaSettingsPageState extends State<LaoMaSettingsPage> {
  List<String> _sources = [];
  List<String> _disabled = [];
  @override
  void initState() { super.initState(); _load(); }
  _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sources = prefs.getStringList('all_sources') ?? ['ting78.com', 'shuyinfm.com', 'huanting.cc', 'tingsm.com', 'ting74.org', 'ting27.com'];
      _disabled = prefs.getStringList('disabled_sources') ?? [];
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text("书源管理")),
    body: ListView(children: [
      ..._sources.map((s) => CheckboxListTile(
        title: Text(s), value: !_disabled.contains(s),
        onChanged: (v) async {
          setState(() { v! ? _disabled.remove(s) : _disabled.add(s); });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('disabled_sources', _disabled);
        },
      )).toList(),
      ListTile(title: Text("微信客服：q13978984")),
    ]),
  );
}
