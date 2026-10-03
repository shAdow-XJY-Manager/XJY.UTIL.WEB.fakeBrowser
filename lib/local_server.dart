import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_static/shelf_static.dart';

class LocalSiteServer {
  HttpServer? _server;
  bool _starting=false;
  int _generation=0;
  bool get running=>_server!=null;
  int? get port=>_server?.port;
  Future<void> start(String root,int port)async{
    if(_server!=null||_starting)throw const FileSystemException('服务已经启动或正在启动');
    final generation=_generation;
    _starting=true;
    try{
    if(port<1024||port>65535)throw const FormatException('端口需为 1024–65535');
    if(!await Directory(root).exists())throw const FileSystemException('网页根目录不存在');
    if(!await File('$root/custom_search_page/index.html').exists()&&!await File('$root/noteview/index.html').exists())throw const FileSystemException('目录内没有可启动站点，请先放入 custom_search_page/index.html 或 noteview/index.html');
    final handlers=<String,Handler>{};
    for(final folder in ['custom_search_page','noteview']){
      final directory=path.join(root,folder);
      if(await Directory(directory).exists())handlers[folder]=createStaticHandler(directory,defaultDocument:'index.html');
    }
    Future<Response> route(Request request)async{
      final segments=request.url.pathSegments;
      if(segments.isEmpty||segments.any((s)=>s=='..'||s.contains('/')||s.contains('\\'))||!handlers.containsKey(segments.first))return Response.notFound('未找到站点。可用路径：/custom_search_page/ 或 /noteview/');
      final response=await handlers[segments.first]!(request.change(path:request.url.path.split('/').first));
      return response.change(headers:{...response.headers,'x-content-type-options':'nosniff'});
    }
    final server=await serve(route,InternetAddress.loopbackIPv4,port);
    if(generation!=_generation){await server.close(force:true);throw const FileSystemException('启动任务已取消');}
    _server=server;
    }finally{_starting=false;}
  }
  Future<void> stop()async{_generation++;final server=_server;_server=null;if(server!=null)await server.close(force:true);}
}
Future<void> openLocalSite(String url)async{
  final uri=Uri.parse(url);
  if(uri.host!='127.0.0.1'||uri.scheme!='http')throw const FormatException('只能打开本机站点');
  final ProcessResult result;
  if(Platform.isMacOS){result=await Process.run('open',[url]);}
  else if(Platform.isWindows){result=await Process.run('rundll32',['url.dll,FileProtocolHandler',url]);}
  else if(Platform.isLinux){result=await Process.run('xdg-open',[url]);}
  else{throw const FileSystemException('此平台无法打开桌面浏览器');}
  if(result.exitCode!=0)throw const FileSystemException('无法打开浏览器，请复制链接手动访问');
}
