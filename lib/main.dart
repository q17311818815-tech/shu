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
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: '精准搜书'),
          NavigationDestination(icon: Icon(Icons.person), label: '个人中心'),
        ],
      ),
    );
  }
}

// --- 首页：书源内关联搜索 ---
class LaoMaSearchPage extends StatefulWidget {
  @override
  _LaoMaSearchPageState createState() => _LaoMaSearchPageState();
}

class _LaoMaSearchPageState extends State<LaoMaSearchPage> {
  final TextEditingController _input = TextEditingController();
  List<Map<String, String>> _results = [];
  List<String> _suggestions = []; 
  bool _isLoading = false;

  // --- 核心修改：去书源站抓取关联词 ---
  Future<void> _getSuggestions(String query) async {
    if (query.isEmpty) { setState(() => _suggestions = []); return; }
    
    final prefs = await SharedPreferences.getInstance();
    List<String> allSources = prefs.getStringList('all_sources') ?? ['ting78.com', 'shuyinfm.com'];
    List<String> disabled = prefs.getStringList('disabled_sources') ?? [];
    List<String> activeSources = allSources.where((s) => !disabled.contains(s)).toList();

    if (activeSources.isEmpty) return;

    try {
      // 逻辑：利用书源站的站内搜索接口来获取关联建议
      // 这里以百度站内搜索镜像为例，精准锁定你选的书源
      final res = await Dio().get(
        "https://suggestion.baidu.com/5a?wd=site:${activeSources[0]} $query",
      );
      String data = res.data.toString();
      if (data.contains("s:[")) {
        String s = data.split("s:[")[1].split("]")[0];
        List<String> list = s.split(",").map((e) => e.replaceAll('"', '').replaceAll('site:${activeSources[0]} ', '')).toList();
        setState(() => _suggestions = list.take(6).toList());
      }
    } catch (e) {
      print("关联失败: $e");
    }
  }

  Future<void> _search(String key) async {
    if (key.isEmpty) return;
    setState(() { _isLoading = true; _results = []; _suggestions = []; FocusScope.of(context).unfocus(); });
    
    final prefs = await SharedPreferences.getInstance();
    List<String> allSources = prefs.getStringList('all_sources') ?? ['ting78.com', 'shuyinfm.com', 'youts.net', 'wdts.top'];
    List<String> disabled = prefs.getStringList('disabled_sources') ?? [];
    List<String> activeSources = allSources.where((s) => !disabled.contains(s)).toList();

    try {
      // 精准限制在勾选的书源域名内搜索
      String siteQuery = activeSources.map((s) => "site:$s").join(" OR ");
      String searchUrl = "https://www.baidu.com/s?wd=$siteQuery $key";
      
      final res = await Dio().get(searchUrl, options: Options(headers: {'User-Agent': 'Mozilla/5.0'}));
      final doc = parse(res.data);
      final items = doc.querySelectorAll('div.result.c-container');
      
      setState(() => _results = items.map((e) => {
        'title': e.querySelector('h3.t > a')?.text ?? '听书资源',
        'url': e.querySelector('h3.t > a')?.attributes['href'] ?? '',
      }).where((m) => m['url']!.isNotEmpty).toList());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(title: Text('老马精准听书'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(15),
            child: Column(
              children: [
                TextField(
                  controller: _input,
                  onChanged: _getSuggestions,
                  decoration: InputDecoration(
                    hintText: "书源库内精准检索...",
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: IconButton(icon: Icon(Icons.send, color: Colors.green), onPressed: () => _search(_input.text)),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  ),
                  onSubmitted: _search,
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]),
                    child: Column(children: _suggestions.map((s) => ListTile(title: Text(s, style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)), dense: true, onTap: () { _input.text = s; _search(s); })).toList()),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading ? Center(child: CircularProgressIndicator()) : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) => Card(
                margin: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: ListTile(
                  leading: Icon(Icons.play_arrow, color: Colors.green),
                  title: Text(_results[index]['title']!, style: TextStyle(fontSize: 14)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
                    appBar: AppBar(title: Text("老马纯净播放")),
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

class LaoMaSettingsPage extends StatefulWidget {
  @override
  _LaoMaSettingsPageState createState() => _LaoMaSettingsPageState();
}

class _LaoMaSettingsPageState extends State<LaoMaSettingsPage> {
  List<String> _sources = [];
  List<String> _disabled = [];
  final TextEditingController _addController = TextEditingController();

  @override
  void initState() { super.initState(); _loadData(); }

  _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sources = prefs.getStringList('all_sources') ?? ['shuyinfm.com', 'huanting.cc', 'ting78.com', 'tingsm.com', 'ting74.org', 'ting27.com'];
      _disabled = prefs.getStringList('disabled_sources') ?? [];
    });
  }

  _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('all_sources', _sources);
    await prefs.setStringList('disabled_sources', _disabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(title: Text("个人中心"), centerTitle: true),
      body: ListView(
        children: [
          Container(
            padding: EdgeInsets.all(20), color: Colors.white,
            child: Row(children: [
              CircleAvatar(radius: 30, backgroundColor: Colors.green[100], child: Icon(Icons.person, color: Colors.green)),
              SizedBox(width: 15),
              Text("老马至尊会员", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
          Padding(padding: EdgeInsets.all(16), child: Text("管理书源（关联词将从开启的书源中获取）", style: TextStyle(color: Colors.grey, fontSize: 12))),
          ..._sources.map((s) => CheckboxListTile(
            title: Text(s),
            value: !_disabled.contains(s),
            onChanged: (val) { setState(() { val! ? _disabled.remove(s) : _disabled.add(s); }); _saveData(); },
            secondary: IconButton(icon: Icon(Icons.delete_outline), onPressed: () { setState(() { _sources.remove(s); }); _saveData(); }),
          )).toList(),
          Padding(
            padding: EdgeInsets.all(15),
            child: Row(children: [
              Expanded(child: TextField(controller: _addController, decoration: InputDecoration(hintText: "添加新域名", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
              IconButton(icon: Icon(Icons.add_circle, color: Colors.green, size: 35), onPressed: () {
                if (_addController.text.isNotEmpty) { setState(() => _sources.add(_addController.text)); _addController.clear(); _saveData(); }
              }),
            ]),
          ),
          ListTile(leading: Icon(Icons.contact_support), title: Text("客服微信：q13978984")),
        ],
      ),
    );
  }
}
