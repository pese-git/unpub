import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:args/args.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:prometheus_client_shelf/shelf_handler.dart';
import 'package:unpub/unpub.dart' as unpub;

main(List<String> args) async {
  var env = Platform.environment;

  env.forEach((k, v) => print("Key=$k Value=$v"));

  var parser = ArgParser();
  parser.addOption('host', abbr: 'h', defaultsTo: '0.0.0.0');
  parser.addOption('port', abbr: 'p', defaultsTo: '4000');

  parser.addOption('db-host', defaultsTo: 'localhost');
  parser.addOption('db-port', defaultsTo: '27017');
  parser.addOption('db-name', defaultsTo: 'unpub');

  parser.addOption('db-username', defaultsTo: 'root');
  parser.addOption('db-password', defaultsTo: 'root');

  parser.addOption('database',
      abbr: 'd', defaultsTo: 'mongodb://localhost:27017/dart_pub');
  parser.addOption('cache-path', abbr: 'c', defaultsTo: '/unpub-packages');
  parser.addOption('proxy-origin', abbr: 'o', defaultsTo: '');

  var results = parser.parse(args);

  var host = results['host'] as String;
  var port = int.parse(results['port'] as String);
  var dbUri = results['database'] as String;
  var proxy_origin = results['proxy-origin'] as String;
  var cache_path = results['cache-path'] as String;

  var dbHost = results['db-host'] as String;
  var dbPort = results['db-port'] as String;
  var dbName = results['db-name'] as String;
  var dbUsername = results['db-username'] as String;
  var dbPassword = results['db-password'] as String;

  if (results.rest.isNotEmpty) {
    print('Got unexpected arguments: "${results.rest.join(' ')}".\n\nUsage:\n');
    print(parser.usage);
    exit(1);
  }

  dbUri =
      'mongodb://${dbUsername}:${dbPassword}@${dbHost}:${dbPort}/${dbName}?authSource=admin&retryWrites=false';

  print('Environment:');
  print('host: $host');
  print('port: $port');
  print('dbUri: $dbUri');
  print('proxy_origin: $proxy_origin');
  print('cache_path: $cache_path');

  final db = Db(dbUri);
  await db.open();

  var baseDir = path.absolute(cache_path);

  print('base Dir: $baseDir');

  var app = unpub.App(
      metaStore: unpub.MongoStore(db),
      packageStore: unpub.FileStore(baseDir),
      proxy_origin:
          proxy_origin.trim().isEmpty ? null : Uri.parse(proxy_origin));

  app.router.get('/metrics', prometheusHandler());

  var server = await app.serve(host, port);
  print('Serving at http://${server.address.host}:${server.port}');
}
