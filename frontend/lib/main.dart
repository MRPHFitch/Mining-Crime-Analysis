import 'package:flutter/material.dart';
import 'themes.dart';
import 'pages/home.dart';
import 'pages/seasons.dart';
import 'pages/sequences.dart';
import 'pages/segment.dart';
import 'pages/data.dart';
import 'pages/charts.dart';

void main() {
  runApp(const CrimeAnalysisApp());
}

class CrimeAnalysisApp extends StatefulWidget {
  const CrimeAnalysisApp({super.key});
  @override
  CrimeAnalysisAppState createState()=>CrimeAnalysisAppState();
}
class CrimeAnalysisAppState extends State<CrimeAnalysisApp>{
  //Allow use of Dark mode
  ThemeMode theMode=ThemeMode.system;
  bool isCreated=false;

  //Allow toggling of dark mode
  void toggleTheme(){
    setState((){
      theMode=theMode==ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Crime Analysis',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: theMode,
      initialRoute: '/home',
      routes: {
        '/home': (context)=>HomePage(toggleTheme: toggleTheme),
        '/segment': (context)=>SegmentPage(),
        '/seasons': (context)=>SeasonsPage(),
        '/sequences': (content)=>SequencesPage(),
        '/data': (context)=>DataPage(),
        '/charts':(context)=>ChartsPage(),
      },
      home: HomePage(toggleTheme: toggleTheme),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const HomeScreen({super.key, required this.toggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crime Analysis"),  //Set the title for the page
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed:widget.toggleTheme,
          )
        ]
      ),
      //List out each of the options
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.timeline),
            title: Text("Segment Crime on Time and Location"),
            onTap: ()=>Navigator.pushNamed(context, '/segment'),
          ),
          ListTile(
            leading: Icon(Icons.calendar_today),
            title: Text("Seasonal Crime Patterns"),
            onTap: ()=>Navigator.pushNamed(context, '/seasons'),
          ),
          ListTile(
            leading: Icon(Icons.repeat),
            title: Text("Recurring Crime Sequences"),
            onTap: ()=>Navigator.pushNamed(context, '/sequences'),
          ),
          ListTile(
            leading: Icon(Icons.data_exploration),
            title: Text("Data Used"),
            onTap: ()=>Navigator.pushNamed(context, '/data'),
          ),
          ListTile(
            leading: Icon(Icons.map_rounded),
            title: Text("Charts and Heatmaps"),
            onTap: ()=>Navigator.pushNamed(context, '/charts'),
          ),
        ],
      )
    );
  }
}
