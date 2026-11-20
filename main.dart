import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

const navy = Color(0xFF142D45);
const blue = Color(0xFF2878A8);
const gold = Color(0xFFE7AD48);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(url: url, anonKey: key);
  }
  runApp(const NyalaApp());
}

class NyalaApp extends StatelessWidget {
  const NyalaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'نيالا ماركت',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: blue),
      scaffoldBackgroundColor: const Color(0xFFF4F7FA),
      fontFamily: 'Arial',
      appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white),
    ),
    home: const Directionality(textDirection: TextDirection.rtl, child: HomePage()),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  List<Map<String,dynamic>> listings = [];
  List<Map<String,dynamic>> categories = [];
  bool loading = true;
  int tab = 0;
  final search = TextEditingController();
  bool get configured => Supabase.instance.isInitialized;
  @override void initState(){super.initState();load();}
  Future<void> load() async {
    if (!configured) { setState(()=>loading=false); return; }
    try {
      final result = await Supabase.instance.client.from('listings')
        .select('id,title,price,currency,city,description,categories(name_ar),profiles(verified_seller)')
        .eq('status','active').order('created_at',ascending:false).limit(30);
      final cats = await Supabase.instance.client.from('categories')
        .select('id,name_ar,slug').eq('active',true).order('sort_order');
      if(mounted) setState(() {
        listings = List<Map<String,dynamic>>.from(result);
        categories = List<Map<String,dynamic>>.from(cats);
        loading = false;
      });
    } catch (_) { if(mounted)setState(()=>loading=false); }
  }
  @override Widget build(BuildContext context) {
    final filtered = listings.where((e)=>(e['title']??'').toString().toLowerCase().contains(search.text.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('نيالا ماركت',style: TextStyle(fontWeight: FontWeight.bold)),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),
      body: RefreshIndicator(onRefresh:load,child: ListView(padding:const EdgeInsets.all(16),children:[
        Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[navy,blue]),borderRadius:BorderRadius.circular(20)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('سوقك السوداني في مكان واحد',style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.bold)),
          SizedBox(height:6),Text('اكتشف، قارن، وتواصل مع البائع',style:TextStyle(color:Colors.white70))
        ])),
        const SizedBox(height:18),
        TextField(controller:search,onChanged:(_)=>setState((){}),decoration:InputDecoration(hintText:'ابحث عن سيارة، هاتف، منزل...',prefixIcon:const Icon(Icons.search),filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none))),
        const SizedBox(height:20),const Text('الأقسام الرئيسية',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
        const SizedBox(height:10),
        GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:3,childAspectRatio:1.05,mainAxisSpacing:9,crossAxisSpacing:9,children:[
          for(final c in (categories.isEmpty ? [
            {'name_ar':'السيارات','slug':'vehicles'},{'name_ar':'الإلكترونيات','slug':'electronics'},{'name_ar':'المنزل والأثاث','slug':'home-furniture'},{'name_ar':'العقارات','slug':'real-estate'},{'name_ar':'الأزياء','slug':'fashion'},{'name_ar':'المعدات','slug':'equipment'}
          ]:categories))
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_emoji(c['slug']??''), style: const TextStyle(fontSize:27)),
                const SizedBox(height:5),
                Text(c['name_ar']??'', textAlign: TextAlign.center, style: const TextStyle(fontSize:12,fontWeight:FontWeight.w600))
              ])
            )
        ]),
        const SizedBox(height:20),const Text('أحدث الإعلانات',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
        if(loading) const Padding(padding:EdgeInsets.all(30),child:Center(child:CircularProgressIndicator())),
        if(!loading && filtered.isEmpty) const Padding(padding:EdgeInsets.all(22),child:Text('لا توجد إعلانات منشورة حالياً.')),
        for(final item in filtered) Card(color:Colors.white,margin:const EdgeInsets.only(top:10),child:ListTile(leading:Container(width:58,height:58,decoration:BoxDecoration(color:const Color(0xFFEAF0F5),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.photo_outlined,color:blue)),title:Text('${item['title']??''}${(item['profiles'] is Map && item['profiles']['verified_seller']==true) ? '  ✓ بائع موثّق' : ''}'),subtitle:Text(item['city']??''),trailing:Text(item['price']==null?'تواصل': '${item['price']} ${item['currency']??'SDG'}',style:const TextStyle(color:blue,fontWeight:FontWeight.bold)),
          onLongPress:()=>_reportListing(context,item['id'].toString())))
      ])),
      floatingActionButton: FloatingActionButton.extended(backgroundColor:gold,onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AddListingPage())).then((_){load();}),icon:const Icon(Icons.add),label:const Text('أضف إعلاناً')),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[
        NavigationDestination(icon:Icon(Icons.home_outlined),label:'الرئيسية'),
        NavigationDestination(icon:Icon(Icons.favorite_border),label:'المفضلة'),
        NavigationDestination(icon:Icon(Icons.chat_bubble_outline),label:'الرسائل'),
        NavigationDestination(icon:Icon(Icons.person_outline),label:'حسابي')
      ]),
    );
  }
  Future<void> _reportListing(BuildContext context, String listingId) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سجّل الدخول للإبلاغ عن إعلان')));
      return;
    }
    const reasons = {'fraud':'اشتباه احتيال','fake_item':'المنتج غير مطابق','wrong_category':'قسم غير صحيح','prohibited':'محتوى مخالف','duplicate':'إعلان مكرر','other':'سبب آخر'};
    String selected = 'fraud';
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx,setDialog) => AlertDialog(
      title: const Text('الإبلاغ عن الإعلان'),
      content: DropdownButtonFormField<String>(value:selected,items:reasons.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setDialog(()=>selected=v??'fraud')),
      actions: [TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('إرسال'))],
    )));
    if (confirmed != true) return;
    try {
      await client.from('listing_reports').insert({'listing_id':listingId,'reporter_id':user.id,'reason':selected});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم استلام البلاغ للمراجعة')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذر إرسال البلاغ. ربما سبق الإبلاغ عن هذا الإعلان.')));
    }
  }
  String _emoji(String s)=>switch(s){'vehicles'=>'🚘','electronics'=>'📱','home-furniture'=>'🛋️','real-estate'=>'🏠','fashion'=>'👕','equipment'=>'🧰',_=>'📦'};
}

class AddListingPage extends StatefulWidget { const AddListingPage({super.key}); @override State<AddListingPage> createState()=>_AddListingPageState(); }
class _AddListingPageState extends State<AddListingPage>{
 final title=TextEditingController(),description=TextEditingController(),price=TextEditingController(),city=TextEditingController(text:'نيالا');
 String? categoryId; String condition='used'; bool saving=false;
 List<Map<String,dynamic>> cats=[];
 @override void initState(){super.initState();_loadCats();}
 Future<void> _loadCats()async{if(!Supabase.instance.isInitialized)return;final r=await Supabase.instance.client.from('categories').select('id,name_ar').eq('active',true).order('sort_order');if(mounted)setState(()=>cats=List<Map<String,dynamic>>.from(r));}
 Future<void> save()async{
  final client=Supabase.instance.client; final user=client.auth.currentUser;
  if(user==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('سجّل الدخول أولاً لإضافة إعلان')));return;}
  if(title.text.trim().length<5||categoryId==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('أدخل عنواناً واختر القسم')));return;}
  setState(()=>saving=true);
  try{await client.from('listings').insert({'seller_id':user.id,'category_id':categoryId,'title':title.text.trim(),'description':description.text.trim(),'price':double.tryParse(price.text),'city':city.text.trim(),'condition':condition,'status':'pending'});if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم إرسال إعلانك للمراجعة')));Navigator.pop(context);}}
  catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر الحفظ: $e')));}
  if(mounted)setState(()=>saving=false);
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('إضافة إعلان')),body:ListView(padding:const EdgeInsets.all(18),children:[
  TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان الإعلان')),
  const SizedBox(height:12),DropdownButtonFormField<String>(value:categoryId,decoration:const InputDecoration(labelText:'القسم'),items:cats.map((c)=>DropdownMenuItem(value:c['id'] as String,child:Text(c['name_ar']))).toList(),onChanged:(v)=>setState(()=>categoryId=v)),
  const SizedBox(height:12),TextField(controller:description,maxLines:4,decoration:const InputDecoration(labelText:'الوصف')),
  const SizedBox(height:12),TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'السعر بالجنيه السوداني')),
  const SizedBox(height:12),TextField(controller:city,decoration:const InputDecoration(labelText:'المدينة / المنطقة')),
  const SizedBox(height:12),DropdownButtonFormField(value:condition,decoration:const InputDecoration(labelText:'الحالة'),items:const[DropdownMenuItem(value:'used',child:Text('مستعمل')),DropdownMenuItem(value:'new',child:Text('جديد'))],onChanged:(v)=>setState(()=>condition=v??'used')),
  const SizedBox(height:22),FilledButton(onPressed:saving?null:save,child:Text(saving?'جارٍ الحفظ…':'إرسال للمراجعة'))
 ]));
}
