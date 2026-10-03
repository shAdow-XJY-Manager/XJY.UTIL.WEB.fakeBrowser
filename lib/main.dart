import 'dart:io';
import 'package:flutter/material.dart';
import 'local_server.dart';
import 'service/app_path.dart';
import 'theme/frequency_theme.dart';
void main()=>runApp(const MyApp());
class MyApp extends StatelessWidget{const MyApp({super.key});@override Widget build(BuildContext context)=>MaterialApp(title:'本地网页启动器',debugShowCheckedModeBanner:false,theme:FrequencyTheme.dark(),home:const LocalSitesPage());}
class LocalSitesPage extends StatefulWidget{const LocalSitesPage({super.key});@override State<LocalSitesPage> createState()=>_LocalSitesPageState();}
class _LocalSitesPageState extends State<LocalSitesPage>{
  final root=TextEditingController(),port=TextEditingController(text:'8080'),server=LocalSiteServer();bool busy=true;String error='';
  @override void initState(){super.initState();init();}
  Future<void> init()async{try{final app=AppPath();await app.init();if(mounted)root.text=app.getWebFilePath();}catch(_){if(mounted)error='无法创建默认网页目录，请输入一个已有目录。';}finally{if(mounted)setState(()=>busy=false);}}
  @override void dispose(){server.stop();root.dispose();port.dispose();super.dispose();}
  Future<void> toggle()async{setState((){busy=true;error='';});try{if(server.running){await server.stop();}else{final value=int.tryParse(port.text);if(value==null)throw const FormatException('端口必须是整数');await server.start(root.text.trim(),value);}}catch(e){if(mounted)setState(()=>error=e is SocketException?'端口无法监听，请换一个端口或停止占用进程。':e is FileSystemException?e.message:e is FormatException?e.message:e.toString());}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> open(String folder)async{try{await openLocalSite('http://127.0.0.1:${server.port}/$folder/');}catch(e){if(mounted)setState(()=>error=e is FileSystemException?e.message:e.toString());}}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('本地网页启动器')),body:SingleChildScrollView(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:960),child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('把本地网页，\n带到浏览器里。',style:TextStyle(fontSize:40,fontWeight:FontWeight.w800)),const SizedBox(height:16),const Text('桌面静态服务器 · 仅本机访问 · 不代理互联网网站',style:TextStyle(fontSize:16,color:FrequencyPalette.muted)),const SizedBox(height:32),
    Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:FrequencyPalette.surface,border:Border.all(color:FrequencyPalette.border),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      TextField(controller:root,enabled:!busy&&!server.running,decoration:const InputDecoration(labelText:'网页根目录',helperText:'目录内应包含 custom_search_page/ 或 noteview/，每个站点有 index.html。')),const SizedBox(height:20),SizedBox(width:220,child:TextField(controller:port,enabled:!busy&&!server.running,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'本机端口 / 1024–65535'))),const SizedBox(height:24),
      FilledButton.icon(onPressed:busy?null:toggle,icon:Icon(server.running?Icons.stop_rounded:Icons.play_arrow_rounded),label:Text(busy?'处理中…':server.running?'停止服务':'启动服务')),
      const SizedBox(height:16),Semantics(liveRegion:true,child:Text(server.running?'正在运行 · http://127.0.0.1:${server.port}/':'服务未启动',style:TextStyle(color:server.running?FrequencyPalette.success:FrequencyPalette.muted))),
      if(error.isNotEmpty) Padding(padding:const EdgeInsets.only(top:16),child:Text(error,style:const TextStyle(color:FrequencyPalette.error))),
    ])),const SizedBox(height:24),
    for(final entry in [('custom_search_page','搜索主页'),('noteview','笔记网页')])Container(margin:const EdgeInsets.only(bottom:16),padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:FrequencyPalette.surface,borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(entry.$2,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w700)),const SizedBox(height:8),SelectableText(server.running?'http://127.0.0.1:${server.port}/${entry.$1}/':'${entry.$1}/index.html',style:const TextStyle(color:FrequencyPalette.muted)),const SizedBox(height:8),Text(root.text.isNotEmpty&&File('${root.text}/${entry.$1}/index.html').existsSync()?'已发现站点文件':'尚未放入 index.html',style:const TextStyle(color:FrequencyPalette.muted)),const SizedBox(height:12),OutlinedButton.icon(onPressed:server.running&&!busy&&File('${root.text}/${entry.$1}/index.html').existsSync()?()=>open(entry.$1):null,icon:const Icon(Icons.open_in_browser_rounded),label:const Text('在浏览器打开'))])),
    const Text('关闭启动器会停止服务。浏览器最终展示内容取决于你放入目录的网页；外站是否可嵌入由目标站点限制决定。',style:TextStyle(color:FrequencyPalette.muted)),
  ]))))));
}
