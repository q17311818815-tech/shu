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
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: '搜索发现'),
          NavigationDestination(icon: Icon(Icons.person), label: '个人中心'),
        ],
      ),
    );
  }
}

class LaoMaSearchPage extends StatefulWidget {
  @override
  _LaoMaSearchPageState createState() => _LaoMaSearchPageState();
}

class _LaoMaSearchPageState extends State<LaoMaSearchPage> {
  final TextEditingController _input = TextEditingController();
  List<Map<String, String>> _results = [];
  bool _isLoading = false;

  Future<void> _search(String key) async {
    if (key.isEmpty) return;
    setState(() { _isLoading = true; _results = []; FocusScope.of(context).unfocus(); });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> sources = prefs.getStringList('all_sources') ?? ['ting78.com', 'shuyinfm.com', 'huanting.cc'];
      List<String> disabled = prefs.getStringList('disabled_sources') ?? [];
      List<String> active = sources.where((s) => !disabled.contains(s)).toList();

      if (active.isEmpty) {
        throw "请先在个人中心开启书源";
      }

      String siteQuery = active.map((s) => "site:$s").join(" OR ");
      // 增加超时设置，防止无限等待
      final dio = Dio(BaseOptions(connectTimeout: Duration(seconds: 10)));
      final res = await dio.get("https://www.baidu.com/s?wd=$siteQuery $key", 
          options: Options(headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}));
      
      final doc = parse(res.data);
      final items = doc.querySelectorAll('div.result.c-container');
      
      setState(() {
        _results = items.map((e) => {
          'title': e.querySelector('h3.t > a')?.text ?? '未知资源',
          'url': e.querySelector('h3.t > a')?.attributes['href'] ?? '',
        }).where((m) => m['url']!.isNotEmpty).toList();
      });
      
      if (_results.isEmpty) throw "未搜到资源，请尝试更换关键词或书源";

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("提示: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(title: Text('老马精准听书 Pro')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(15),
            child: TextField(
              controller: _input,
              decoration: InputDecoration(
                hintText: "输入书名搜精准资源...",
                suffixIcon: IconButton(icon: Icon(Icons.send, color: Colors.green), onPressed: () => _search(_input.text)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                filled: true, fillColor: Colors.white,
              ),
              onSubmitted: _search,
            ),
          ),
          Expanded(
            child: _isLoading 
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("全网书源搜寻中...码数：q13978984")]))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) => Card(
                    margin: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    child: ListTile(
                      title: Text(_results[index]['title']!, style: TextStyle(fontSize: 14)),
                      trailing: Icon(Icons.play_circle_fill, color: Colors.green),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
                        appBar: AppBar(title: Text("正在播放")),
                        body: WebViewWidget(controller: WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..loadRequest(Uri.parse(_results[index]['url']!))),
                      ))),
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
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
    setState(() {
      _sources = prefs.getStringList('all_sources') ?? ['shuyinfm.com', 'huanting.cc', 'ting78.com', 'tingsm.com', 'ting74.org', 'ting27.com'];
      _disabled = prefs.getStringList('disabled_sources') ?? [];
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("个人中心")),
      body: ListView(children: [
        ..._sources.map((s) => CheckboxListTile(
          title: Text(s), value: !_disabled.contains(s), activeColor: Colors.green,
          onChanged: (v) async {
            setState(() { v! ? _disabled.remove(s) : _disabled.add(s); });
            final prefs = await SharedPreferences.getInstance();
            await prefs.setStringList('disabled_sources', _disabled);
          },
        )).toList(),
      ]),
    );
  }
}
