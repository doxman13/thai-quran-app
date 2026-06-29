import 'dart:io';
import 'dart:convert';
void main() async {
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse('https://api.quran.com/api/v4/verses/by_key/2:2?words=true&word_fields=text_qpc_hafs,text_uthmani,text_uthmani_tajweed'));
  final res = await req.close();
  final str = await res.transform(utf8.decoder).join();
  final map = jsonDecode(str);
  for(var word in map['verse']['words']) {
    print('text_qpc_hafs: ${word["text_qpc_hafs"]} | text_uthmani: ${word["text_uthmani"]} | tajweed: ${word["text_uthmani_tajweed"]}');
  }
}
