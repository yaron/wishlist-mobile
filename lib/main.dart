// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:random_string/random_string.dart';

void main() => runApp(MyApp());
final String baseUrl = "https://www.yaeltal.nl/";

class MyApp extends StatefulWidget {
  MyApp({Key key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<List<WishList>> wishList;
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    wishList = addSecrets(fetchList());
  }

  Future<void> claimItem(int id) async {
    final SharedPreferences prefs = await _prefs;

    String secret = randomAlphaNumeric(10);
    await http.get(baseUrl+'api.php?action=claim&id='+id.toString()+'&code='+secret);
    print("claiming "+ id.toString()+" with secret " + secret);

    await prefs.setString('secret-'+id.toString(), secret);
    setState(() {
      wishList = addSecrets(fetchList());
    });
  }

  Future<void> unclaimItem(int id, String secret) async {
    final SharedPreferences prefs = await _prefs;
    print("unclaiming " +id.toString());
    await http.get(baseUrl+'api.php?action=unclaim&id='+id.toString()+'&code='+secret);
    await prefs.remove('secret-'+id.toString());
    setState(() {
      wishList = addSecrets(fetchList());
    });
  }

  Future<List<WishList>> addSecrets(Future<List<WishList>> wishList) async {
    final SharedPreferences prefs = await _prefs;
    var list = await wishList;
    list.forEach((e) =>
      e.secret = prefs.getString('secret-'+e.rowId.toString())
    );

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wishlist',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Wishlist'),
        ),
        body: Center(
          child: FutureBuilder<List<WishList>>(
            future: wishList,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return ListView.separated(
                    itemCount: snapshot.data.length,
                    itemBuilder: (context, index) {
                      var itemId = snapshot.data[index].rowId;
                      var title = Text(snapshot.data[index].name);
                      var button = InkWell(child:Text('Claimed'));
                      if (snapshot.data[index].status != 2) {
                        button = InkWell(
                          child: Text("Claim"),
                          onTap: () => claimItem(itemId),

                        );
                      }
                      if (snapshot.data[index].status == 2) {
                        title = Text(snapshot.data[index].name, style: TextStyle(decoration: TextDecoration.lineThrough));
                        if (snapshot.data[index].secret != null) {
                          button = InkWell(
                            child: Text("Unclaim"),
                            onTap: () => unclaimItem(itemId, snapshot.data[index].secret),

                          );
                        }
                      }
                      return ListTile(
                        leading: Image.network(snapshot.data[index].img),
                        title: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                child: title,
                                onTap: () => launch(snapshot.data[index].url),
                              )
                            ),
                              Expanded(child: button)
                            ]
                        ),
                        subtitle: Text(snapshot.data[index].price),
                        enabled: snapshot.data[index].status != 2,
                      );

                    },
                    separatorBuilder: (context, index) {
                      return Divider();
                    }
                );
              } else if (snapshot.hasError) {
                return Text("${snapshot.error}");
              }

              // By default, show a loading spinner.
              return CircularProgressIndicator();
            },
          ),
        ),
      ),
    );
  }
}

Future<List<WishList>> fetchList() async {
  final response =
  await http.get(baseUrl+'api.php?action=list');

  if (response.statusCode == 200) {
    // If server returns an OK response, parse the JSON.
    Iterable list = json.decode(response.body);
    return list.map((element) => WishList.fromJson(element)).toList();
  } else {
    // If that response was not OK, throw an error.
    throw Exception('Failed to load list');
  }
}

class WishList {
  final int rowId;
  final String name;
  final String url;
  final String img;
  final String price;
  final int status;
  String secret;

  WishList({this.rowId, this.name, this.url, this.img, this.price, this.status});

  factory WishList.fromJson(Map<String, dynamic> json) {
    if (!json['img'].toString().startsWith('http')) {
      json['img'] = baseUrl+json['img'];
    }

    return WishList(
      rowId: json['rowid'],
      name: json['name'],
      url: json['url'],
      img: json['img'],
      price: json['price'],
      status: json['status'],
    );
  }
}

