
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

void main(){
  runApp(new MaterialApp(
    home: new CommandList(),
  ));
}

class CommandList extends StatefulWidget{
  @override
  CommandListState createState(){
    return new CommandListState();
  }
}

class CommandListState extends State<CommandList>{
  Map decodedMap;
  List data;
  int editable;
  String tempText;

  Future<String> getData() async {
    Dio dio = new Dio();
    Response response = await dio.get(
      "http://your server address/data"
    );
 
    this.setState(() {
      data = json.decode(response.toString());
    });

    return "Success!";
  }

  @override
  void initState(){
    super.initState();
    this.getData();
  }

  @override 
  Widget build(BuildContext context){
    return new Scaffold(
      appBar: new AppBar(backgroundColor: Colors.green,title: new Text("Remote Control Commands"),),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: new ListView.builder(
        itemCount: data==null?0:data.length,
        itemBuilder: (BuildContext context, int index){
          return new ListTile(
            //title: new Text(data[index]["desc"].toString()),
            title: TextField(
              enabled: index == editable,
              onChanged: (text){
                tempText = text;
              },
              controller: TextEditingController.fromValue(TextEditingValue(
                  text: data[index]["desc"].toString(),
                )
              )
            ),
            onTap: ()=> _control(data[index]["key"].toString()),
            onLongPress: ()=> _changeTextFieldStatus(index),
            trailing: new Icon(Icons.keyboard_arrow_right),
          );
        },
      ),
      )
    );
  }

  Future<Null> _refresh() async {
    await Future.delayed(Duration(seconds: 1), () {
      setState(() {
        getData();
      });
    });
  }

  _changeTextFieldStatus(i) {
    setState(() {
      print(editable.toString());
      print(i.toString());
      if(editable == i){
        editable = -1;
        _updateDesc(i,tempText);
        _refresh();
      }
      else{
        editable = i;
      }

    });
  }

}


_control(command) async {
  Dio dio = new Dio();
  await dio.post("http://your server address/command",data:{"topic":"remotecontroltopic","message":command});
}

_updateDesc(id, desc) async{
  Dio dio = new Dio();
  await dio.put("http://your server address/data",data:{"id":id,"desc":desc});
}
