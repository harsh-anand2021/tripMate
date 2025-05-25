import 'package:flutter/material.dart';
class Uihelper {
  static Text showText(text,size,_color){
    return Text(
      text,style: TextStyle(fontSize:size,color:_color,),
      textAlign: TextAlign.center,
    );
  }
}