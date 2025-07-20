import 'package:flutter/material.dart';
import 'package:sbr_chatbot/pages/chatbot.page.dart';
import 'package:sbr_chatbot/pages/login.page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget{
  const MyApp({super.key});
  @override
  Widget build(BuildContext context){
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        "/bot": (context)=>ChatbotPage(),
        "/":(context)=>LoginPage()
      },
      theme: ThemeData(
        primaryColor: Colors.blueGrey
      ),
    );
  }
}
