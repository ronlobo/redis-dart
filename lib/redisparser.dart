/*
 * Free software licenced under 
 * GNU AFFERO GENERAL PUBLIC LICENSE
 * 
 * Check for document LICENCE forfull licence text
 * 
 * Luka Rahne
 */

part of redis;

class RedisError{
  String e;
  RedisError(this.e);
  String toString() { return "RedisError($e)";}
}


class RedisParser{
  static const int CR = 13;
  static const int LF = 10;
  
  static const int TYPE_SS = 43; //+
  static const int TYPE_ERROR = 45; //-
  static const int TYPE_INT =  58; //:
  static const int TYPE_BULK =  36; //$
  static const int TYPE_ARRAY = 42; //*
  
  
  //read untill it finds CR and LF 
  //by protocol it is enough to find just CR and LF folows
  //this method can be used only on types that complies with such rule
  //it consumes both CR and LF from stream, but is not returned
  static Future read_simple(LazyStream s) {
    return s.take_while((c) => (c != CR))
    .then((list) {
      //takeWile consumed CR from stream, 
      //now check for LF
      int size = list.length;
      return s.take_n(1).then((lf){
        if(lf[0] != LF){
          throw("received element is not LF");
        }
        return list;
      });
    });
  }
  
  //return Future<r> if next two elemets are CRLF
  //or thows if failed
  static Future takeCRLF(LazyStream s,r){
    return s.take_n(2).then((data){
      if(data[0] == CR && data[1] == LF){
        return r;
      }
      else{
        throw("expeting CRLF");
      }
    });
  }
  
  static Future parseredisresponse(LazyStream s){
    return s.take_n(1)
    .then((list){
       int cmd = list[0];
       switch(cmd){
         case TYPE_SS:
           return parseSimpleString(s);
         case TYPE_INT:
           return parseInt(s);
         case TYPE_ARRAY:
           return parseArray(s);
         case TYPE_BULK:
           return parseBulk(s);
         case TYPE_ERROR:
           return parseError(s);
         default:
           throw("got element that cant not be parsed");
       }
       
    });
  }
  
  static Future<String> parseSimpleString(LazyStream s){
    return read_simple(s).then((v) => UTF8.decode(v));
  }
  
  static Future<RedisError> parseError(LazyStream s){
    return parseSimpleString(s).then((str) => new RedisError(str));
  }
  
  static Future<int> parseInt(LazyStream s){
    return parseSimpleString(s).then((str) => int.parse(str));
  }
  
  static Future parseBulk(LazyStream s){
    return parseInt(s).then((i){ //get len
      if(i==-1) //null
        return null; 
      if(i>=0){ //i of bulk data
       return s.take_n(i) 
       .then((lst) => takeCRLF(s,UTF8.decode(lst))); //consume CRLF and return decoded list
      }
      else{
        throw("cant process buld data less than -1");
      }
    });
  }
  
  //it first consume array as N and then
  //consume  N elements with parseredisresponse function
  static Future<List> parseArray(LazyStream s){
    //closure
    Future<List> consumeList(LazyStream s,int len,List lst){
      assert(len>=0);
      if(len==0){
        return new Future.value(lst);
      }
      return parseredisresponse(s).then((resp){
        lst.add(resp);
        return consumeList(s,len-1,lst);
      });
    }
    //end of closure
    return parseInt(s).then((i){ //get len
      if(i==-1) //null
        return null; 
      if(i>=0){ //i of array data
          List a = new List();
          return consumeList(s,i,a);
      }
      else{
        throw("cant process array data less than -1");
      }
    });
  }
}

class RedisParserBulkAsIterable extends RedisParser{
  //RedisParser parses bulk as 
  static Future parseBulk(LazyStream s){
    return RedisParser.parseInt(s).then((i){ //get len
      if(i==-1) //null
        return null; 
      if(i>=0){ //i of bulk data
       return s.take_n(i) 
       .then((lst) => RedisParser.takeCRLF(s,UTF8.decode(lst))); //consume CRLF and return decoded list
      }
      else{
        throw("cant process buld data less than -1");
      }
    });
  }
}

