import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WorkerApp());
}

class Worker {
  String id, name, job;
  double dailyWage, overtimeRate;
  double advance, deductions;
  Worker({
    required this.id, required this.name, required this.job,
    required this.dailyWage, this.overtimeRate = 0,
    this.advance = 0, this.deductions = 0,
  });
  Map<String,dynamic> toJson()=> {
    'id':id,'name':name,'job':job,'dailyWage':dailyWage,
    'overtimeRate':overtimeRate,'advance':advance,'deductions':deductions
  };
  factory Worker.fromJson(Map<String,dynamic> j)=>Worker(
    id:j['id'], name:j['name'], job:j['job'],
    dailyWage:(j['dailyWage'] as num).toDouble(),
    overtimeRate:(j['overtimeRate'] as num?)?.toDouble() ?? 0,
    advance:(j['advance'] as num?)?.toDouble() ?? 0,
    deductions:(j['deductions'] as num?)?.toDouble() ?? 0,
  );
}

class Attendance {
  String? checkIn, checkOut;
  DateTime? overtimeStart, overtimeEnd;
  Map<String,dynamic> toJson()=> {
    'checkIn':checkIn,'checkOut':checkOut,
    'overtimeStart':overtimeStart?.toIso8601String(),
    'overtimeEnd':overtimeEnd?.toIso8601String(),
  };
  factory Attendance.fromJson(Map<String,dynamic> j)=>Attendance()
    ..checkIn=j['checkIn']..checkOut=j['checkOut']
    ..overtimeStart=j['overtimeStart']==null?null:DateTime.parse(j['overtimeStart'])
    ..overtimeEnd=j['overtimeEnd']==null?null:DateTime.parse(j['overtimeEnd']);
}

class WorkerApp extends StatelessWidget {
  const WorkerApp({super.key});
  @override Widget build(BuildContext c)=>MaterialApp(
    debugShowCheckedModeBanner:false, title:'DAHAB',
    theme:ThemeData(useMaterial3:true,colorSchemeSeed:const Color(0xFFB88A44),fontFamily:'Arial'),
    home:const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override State<Home> createState()=>_HomeState();
}
class _HomeState extends State<Home> {
  List<Worker> workers=[];
  Map<String,Attendance> today={};
  bool loading=true;

  String get dateKey {
    final n=DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }
  String nowText(){
    final n=DateTime.now();
    final h=n.hour==0?12:(n.hour>12?n.hour-12:n.hour);
    return '${h.toString().padLeft(2,'0')}:${n.minute.toString().padLeft(2,'0')} ${n.hour>=12?'م':'ص'}';
  }

  @override void initState(){super.initState();load();}
  Future<void> load() async {
    final p=await SharedPreferences.getInstance();
    workers=(p.getStringList('workers')??[]).map((x)=>Worker.fromJson(jsonDecode(x))).toList();
    final raw=p.getString('attendance_$dateKey');
    if(raw!=null){
      final m=jsonDecode(raw) as Map<String,dynamic>;
      today=m.map((k,v)=>MapEntry(k,Attendance.fromJson(v)));
    }
    if(workers.isEmpty){
      workers.add(Worker(id:'W-0001',name:'عامل تجريبي',job:'عامل',dailyWage:250,overtimeRate:40));
      await saveWorkers();
    }
    setState(()=>loading=false);
  }
  Future<void> saveWorkers() async {
    final p=await SharedPreferences.getInstance();
    await p.setStringList('workers',workers.map((w)=>jsonEncode(w.toJson())).toList());
  }
  Future<void> saveToday() async {
    final p=await SharedPreferences.getInstance();
    await p.setString('attendance_$dateKey',jsonEncode(today.map((k,v)=>MapEntry(k,v.toJson()))));
  }
  Attendance rec(String id)=>today.putIfAbsent(id,()=>Attendance());

  Future<void> addWorker() async {
    final name=TextEditingController(), job=TextEditingController(),
      wage=TextEditingController(), ot=TextEditingController();
    await showDialog(context:context,builder:(_)=>AlertDialog(
      title:const Text('إضافة عامل'),
      content:SingleChildScrollView(child:Column(children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'اسم العامل')),
        TextField(controller:job,decoration:const InputDecoration(labelText:'الوظيفة')),
        TextField(controller:wage,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'الأجر اليومي')),
        TextField(controller:ot,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'سعر ساعة الإضافي')),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إلغاء')),
        FilledButton(onPressed:()async{
          if(name.text.trim().isEmpty)return;
          final id='W-${(workers.length+1).toString().padLeft(4,'0')}';
          workers.add(Worker(id:id,name:name.text.trim(),
            job:job.text.trim().isEmpty?'عامل':job.text.trim(),
            dailyWage:double.tryParse(wage.text)??0,
            overtimeRate:double.tryParse(ot.text)??0));
          await saveWorkers(); if(mounted){Navigator.pop(context);setState((){});}
        },child:const Text('حفظ'))
      ],
    ));
  }

  Future<void> editMoney(Worker w) async {
    final adv=TextEditingController(text:w.advance.toStringAsFixed(0));
    final ded=TextEditingController(text:w.deductions.toStringAsFixed(0));
    await showDialog(context:context,builder:(_)=>AlertDialog(
      title:Text('الخصومات والسلف - ${w.name}'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:adv,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'السلفة')),
        TextField(controller:ded,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'الخصومات')),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إلغاء')),
        FilledButton(onPressed:()async{
          w.advance=double.tryParse(adv.text)??0;
          w.deductions=double.tryParse(ded.text)??0;
          await saveWorkers();if(mounted){Navigator.pop(context);setState((){});}
        },child:const Text('حفظ'))
      ],
    ));
  }

  Future<void> act(Worker w,String type) async {
    final a=rec(w.id); final n=DateTime.now();
    if(type=='in' && a.checkIn==null)a.checkIn=nowText();
    if(type=='out' && a.checkIn!=null && a.checkOut==null)a.checkOut=nowText();
    if(type=='ot' && a.checkOut!=null){
      if(a.overtimeStart==null)a.overtimeStart=n;
      else if(a.overtimeEnd==null)a.overtimeEnd=n;
    }
    await saveToday();setState((){});
  }

  double otHours(Attendance a){
    if(a.overtimeStart==null)return 0;
    final end=a.overtimeEnd??DateTime.now();
    return end.difference(a.overtimeStart!).inMinutes/60;
  }
  double salaryFor(Worker w){
    final a=rec(w.id);
    final present=a.checkIn!=null?1:0;
    return present*w.dailyWage + otHours(a)*w.overtimeRate - w.advance - w.deductions;
  }

  Widget card(Worker w){
    final a=rec(w.id);
    final running=a.overtimeStart!=null&&a.overtimeEnd==null;
    return Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:7),elevation:2,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
      child:InkWell(
        borderRadius:BorderRadius.circular(20),
        onTap:()=>Navigator.push(context,MaterialPageRoute(
          builder:(_)=>WorkerProfilePage(
            worker:w,
            attendance:a,
            overtimeHours:otHours(a),
            netToday:salaryFor(w),
          ),
        )),
        child:Padding(padding:const EdgeInsets.all(14),child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Row(children:[
            CircleAvatar(child:Text(w.id.substring(2))),
            const SizedBox(width:10),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(w.name,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
              Text('${w.id} • ${w.job}'),
              Text('اليومي: ${w.dailyWage.toStringAsFixed(0)} ج • الإضافي: ${w.overtimeRate.toStringAsFixed(0)} ج/ساعة'),
            ])),
            IconButton(tooltip:'السلف والخصومات',onPressed:()=>editMoney(w),icon:const Icon(Icons.edit_note))
          ]),
          const SizedBox(height:8),
          Wrap(spacing:7,runSpacing:7,children:[
            FilledButton.icon(onPressed:a.checkIn==null?()=>act(w,'in'):null,
              icon:const Icon(Icons.login),label:Text(a.checkIn==null?'دخول':'دخول ${a.checkIn}')),
            FilledButton.icon(onPressed:a.checkIn!=null&&a.checkOut==null?()=>act(w,'out'):null,
              icon:const Icon(Icons.logout),label:Text(a.checkOut==null?'خروج':'خروج ${a.checkOut}')),
            OutlinedButton.icon(onPressed:a.checkOut!=null&&a.overtimeEnd==null?()=>act(w,'ot'):null,
              icon:const Icon(Icons.more_time),
              label:Text(a.overtimeStart==null?'إضافي':(running?'إنهاء الإضافي':'إضافي مكتمل'))),
          ]),
          if(a.checkIn!=null)Padding(padding:const EdgeInsets.only(top:8),
            child:Text('المستحق اليوم تقريباً: ${salaryFor(w).toStringAsFixed(2)} جنيه',
              style:const TextStyle(fontWeight:FontWeight.bold))),
        ]))),
      ),
    );
  }

  void salaries(){
    Navigator.push(context,MaterialPageRoute(builder:(_)=>SalaryPage(workers:workers,today:today,otHours:otHours,salaryFor:salaryFor)));
  }

  @override Widget build(BuildContext context){
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    final present=today.values.where((a)=>a.checkIn!=null).length;
    return Directionality(textDirection:TextDirection.rtl,child:Scaffold(
      appBar:AppBar(title:const Text('DAHAB'),centerTitle:true,actions:[
        IconButton(
          onPressed:()=>Navigator.push(context,MaterialPageRoute(
            builder:(_)=>KioskPage(workers:workers,today:today,action:act)
          )),
          icon:const Icon(Icons.touch_app),
          tooltip:'شاشة تسجيل الحضور',
        ),
        IconButton(onPressed:salaries,icon:const Icon(Icons.payments),tooltip:'الرواتب'),
        IconButton(onPressed:addWorker,icon:const Icon(Icons.person_add)),
      ]),
      body:Column(children:[
        Container(
          margin:const EdgeInsets.fromLTRB(12,12,12,8),
          padding:const EdgeInsets.fromLTRB(16,16,16,12),
          decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(24),
            gradient:const LinearGradient(
              begin:Alignment.topRight,end:Alignment.bottomLeft,
              colors:[Color(0xFFF8F1E6),Color(0xFFEDE0C9)]
            ),
            boxShadow:[BoxShadow(color:Colors.black12,blurRadius:14,offset:Offset(0,6))]
          ),
          child:Column(children:[
            Row(children:[
              Container(
                width:48,height:48,
                decoration:BoxDecoration(
                  color:const Color(0xFFB88A44),
                  borderRadius:BorderRadius.circular(15)
                ),
                child:const Icon(Icons.business_center,color:Colors.white)
              ),
              const SizedBox(width:12),
              const Expanded(child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text('DAHAB',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,letterSpacing:1.5)),
                  Text('إدارة الحضور والرواتب',style:TextStyle(fontSize:12))
                ]
              )),
              Text(dateKey,style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold))
            ]),
            const SizedBox(height:14),
            Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
              stat('العمال',workers.length.toString(),Icons.groups),
              stat('حاضر',present.toString(),Icons.check_circle),
              stat('اليوم',dateKey.substring(8),Icons.today),
            ])
          ])
        ),
        Expanded(child:ListView(children:[
          Padding(
            padding:const EdgeInsets.fromLTRB(12,4,12,10),
            child:SizedBox(
              height:58,
              width:double.infinity,
              child:FilledButton.icon(
                onPressed:()=>Navigator.push(context,MaterialPageRoute(
                  builder:(_)=>KioskPage(workers:workers,today:today,action:act)
                )),
                icon:const Icon(Icons.fingerprint),
                label:const Text('شاشة تسجيل الحضور والانصراف',
                  style:TextStyle(fontSize:16,fontWeight:FontWeight.bold)),
              ),
            ),
          ),
          const Padding(
            padding:EdgeInsets.fromLTRB(18,4,18,8),
            child:Text('حضور اليوم',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))
          ),
          ...workers.map(card)
        ]))
      ]),
      floatingActionButton:FloatingActionButton.extended(onPressed:addWorker,
        icon:const Icon(Icons.add),label:const Text('إضافة عامل')),
    ));
  }
  Widget stat(String t,String v,IconData i)=>Container(
    width:92,
    padding:const EdgeInsets.symmetric(vertical:10,horizontal:7),
    decoration:BoxDecoration(
      color:Colors.white,
      borderRadius:BorderRadius.circular(16),
      boxShadow:[BoxShadow(color:Colors.black.withOpacity(.06),blurRadius:10,offset:const Offset(0,4))]
    ),
    child:Column(children:[
      Icon(i,size:25,color:const Color(0xFFB88A44)),
      const SizedBox(height:4),
      Text(v,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      Text(t,style:const TextStyle(fontSize:12))
    ])
  );
}



class KioskPage extends StatefulWidget {
  final List<Worker> workers;
  final Map<String, Attendance> today;
  final Future<void> Function(Worker, String) action;
  const KioskPage({
    super.key,
    required this.workers,
    required this.today,
    required this.action,
  });
  @override State<KioskPage> createState()=>_KioskPageState();
}

class _KioskPageState extends State<KioskPage> {
  final code=TextEditingController();
  Worker? worker;
  String message='أدخل كود العامل ثم اختر العملية';
  bool busy=false;

  void findWorker() {
    final c=code.text.trim().toUpperCase();
    Worker? found;
    for(final w in widget.workers) {
      if(w.id.toUpperCase()==c) { found=w; break; }
    }
    setState(() {
      worker=found;
      message=found==null ? 'الكود غير موجود' : 'تم التعرف على العامل — اختر العملية';
    });
  }

  Future<void> doAction(String type) async {
    final w=worker;
    if(w==null || busy) return;
    setState(()=>busy=true);
    await widget.action(w,type);
    setState(() {
      busy=false;
      message=type=='in'
          ? 'تم تسجيل الحضور بنجاح'
          : type=='out'
              ? 'تم تسجيل الانصراف بنجاح'
              : 'تم تسجيل الإضافي بنجاح';
    });
    Future.delayed(const Duration(seconds:2),(){
      if(mounted) setState(()=>worker=null);
      code.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final a=worker==null ? null : widget.today[worker!.id];
    final canIn=worker!=null && a?.checkIn==null;
    final canOut=worker!=null && a?.checkIn!=null && a?.checkOut==null;
    final canOt=worker!=null && a?.checkOut!=null && a?.overtimeEnd==null;

    return Directionality(
      textDirection:TextDirection.rtl,
      child:Scaffold(
        backgroundColor:const Color(0xFFF6F3EE),
        appBar:AppBar(
          title:const Text('DAHAB'),
          centerTitle:true,
          backgroundColor:const Color(0xFFB88A44),
          foregroundColor:Colors.white,
        ),
        body:Center(
          child:SingleChildScrollView(
            padding:const EdgeInsets.all(20),
            child:ConstrainedBox(
              constraints:const BoxConstraints(maxWidth:520),
              child:Column(children:[
                Container(
                  width:76,height:76,
                  decoration:BoxDecoration(
                    color:const Color(0xFFB88A44),
                    borderRadius:BorderRadius.circular(24),
                  ),
                  child:const Icon(Icons.fingerprint,color:Colors.white,size:42),
                ),
                const SizedBox(height:12),
                const Text('تسجيل الحضور',style:TextStyle(fontSize:27,fontWeight:FontWeight.w800)),
                const SizedBox(height:4),
                const Text('اكتب كود العامل فقط',style:TextStyle(color:Colors.grey)),
                const SizedBox(height:20),
                TextField(
                  controller:code,
                  textAlign:TextAlign.center,
                  textCapitalization:TextCapitalization.characters,
                  style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold,letterSpacing:2),
                  decoration:InputDecoration(
                    hintText:'W-0001',
                    prefixIcon:const Icon(Icons.badge),
                    suffixIcon:IconButton(onPressed:findWorker,icon:const Icon(Icons.search)),
                    filled:true,
                    fillColor:Colors.white,
                    border:OutlineInputBorder(borderRadius:BorderRadius.circular(18)),
                  ),
                  onSubmitted:(_)=>findWorker(),
                ),
                const SizedBox(height:10),
                Text(message,style:TextStyle(
                  fontWeight:FontWeight.bold,
                  color:worker==null ? Colors.grey : const Color(0xFF6F532B),
                )),
                const SizedBox(height:20),
                if(worker!=null)
                  Container(
                    width:double.infinity,
                    padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(
                      color:Colors.white,
                      borderRadius:BorderRadius.circular(18),
                    ),
                    child:Text(
                      'العامل: ${worker!.name}',
                      textAlign:TextAlign.center,
                      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold),
                    ),
                  ),
                const SizedBox(height:14),
                Row(children:[
                  Expanded(child:actionButton(
                    'حضور',Icons.login,const Color(0xFF2E7D32),canIn,()=>doAction('in')
                  )),
                  const SizedBox(width:10),
                  Expanded(child:actionButton(
                    'انصراف',Icons.logout,const Color(0xFFC62828),canOut,()=>doAction('out')
                  )),
                ]),
                const SizedBox(height:10),
                SizedBox(
                  width:double.infinity,
                  child:actionButton(
                    a?.overtimeStart==null ? 'بدء الإضافي' : 'إنهاء الإضافي',
                    Icons.more_time,const Color(0xFFB88A44),canOt,()=>doAction('ot')
                  ),
                ),
                const SizedBox(height:18),
                TextButton.icon(
                  onPressed:()=>setState(()=>worker=null),
                  icon:const Icon(Icons.clear),
                  label:const Text('مسح الكود'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget actionButton(String title,IconData icon,Color color,bool enabled,VoidCallback onTap) {
    return SizedBox(
      height:68,
      child:FilledButton.icon(
        onPressed:enabled && !busy ? onTap : null,
        icon:Icon(icon,size:28),
        label:Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
        style:FilledButton.styleFrom(
          backgroundColor:color,
          foregroundColor:Colors.white,
          disabledBackgroundColor:Colors.grey.shade300,
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
        ),
      ),
    );
  }
}

class WorkerProfilePage extends StatelessWidget {
  final Worker worker;
  final Attendance attendance;
  final double overtimeHours;
  final double netToday;

  const WorkerProfilePage({
    super.key,
    required this.worker,
    required this.attendance,
    required this.overtimeHours,
    required this.netToday,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ملف العامل'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.receipt_long),
              onPressed: () => showReceipt(context),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            header(),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: metric('أجر اليوم', '${worker.dailyWage.toStringAsFixed(0)} ج', Icons.payments)),
              const SizedBox(width: 8),
              Expanded(child: metric('الإضافي', '${overtimeHours.toStringAsFixed(2)} س', Icons.more_time)),
              const SizedBox(width: 8),
              Expanded(child: metric('المستحق', '${netToday.toStringAsFixed(0)} ج', Icons.account_balance_wallet)),
            ]),
            const SizedBox(height: 14),
            section('حالة الحضور اليوم', Icons.fact_check, [
              row('الدخول', attendance.checkIn ?? 'لم يسجل', Icons.login),
              row('الخروج', attendance.checkOut ?? 'لم يسجل', Icons.logout),
              row('الإضافي',
                attendance.overtimeStart == null
                    ? 'لا يوجد'
                    : (attendance.overtimeEnd == null ? 'قيد التشغيل' : 'مكتمل'),
                Icons.more_time),
            ]),
            const SizedBox(height: 12),
            section('السلف والخصومات', Icons.account_balance_wallet, [
              row('السلف', '${worker.advance.toStringAsFixed(2)} جنيه', Icons.arrow_downward),
              row('الخصومات', '${worker.deductions.toStringAsFixed(2)} جنيه', Icons.remove_circle_outline),
              row('الصافي', '${netToday.toStringAsFixed(2)} جنيه', Icons.payments),
            ]),
            const SizedBox(height: 12),
            section('سجل الحضور', Icons.calendar_month, [
              history('اليوم', attendance.checkIn ?? '—', attendance.checkOut ?? '—', overtimeHours),
              history('أمس', '—', '—', 0),
              history('قبل أمس', '—', '—', 0),
            ]),
            const SizedBox(height: 12),
            section('سجل الرواتب', Icons.receipt, [
              salaryRow('الفترة 1 - 15', 'قيد الحساب'),
              salaryRow('الفترة 16 - نهاية الشهر', 'قيد الحساب'),
            ]),
            const SizedBox(height: 12),
            section('الإيصالات', Icons.receipt_long, [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF1E4CE),
                  child: Icon(Icons.receipt_long, color: Color(0xFFB88A44)),
                ),
                title: const Text('إيصال مستحقات', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('العامل: ${worker.name}'),
                trailing: IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: () => showReceipt(context),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget header() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFB88A44), Color(0xFF8D642B)],
      ),
    ),
    child: Row(children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Center(
          child: Text(worker.id.substring(2),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF8D642B))),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(worker.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(worker.id, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          Text(worker.job, style: const TextStyle(color: Colors.white70)),
        ],
      )),
      const Icon(Icons.badge, color: Colors.white, size: 32),
    ]),
  );

  Widget metric(String title, String value, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 9, offset: const Offset(0, 4))],
    ),
    child: Column(children: [
      Icon(icon, color: const Color(0xFFB88A44), size: 24),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      Text(title, style: const TextStyle(fontSize: 11)),
    ]),
  );

  Widget section(String title, IconData icon, List<Widget> children) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Column(children: [
      Row(children: [
        Icon(icon, color: const Color(0xFFB88A44)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 6),
      ...children,
    ]),
  );

  Widget row(String title, String value, IconData icon) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, size: 21, color: const Color(0xFFB88A44)),
    title: Text(title),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  Widget history(String day, String inTime, String outTime, double ot) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text('دخول: $inTime   •   خروج: $outTime'),
    trailing: Text('${ot.toStringAsFixed(1)} س إضافي'),
  );

  Widget salaryRow(String title, String status) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.payments, color: Color(0xFFB88A44)),
    title: Text(title),
    trailing: Text(status, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  void showReceipt(BuildContext context) {
    final no = 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Center(child: Text('إيصال DAHAB', style: TextStyle(fontWeight: FontWeight.w800))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('رقم الإيصال: $no'),
            Text('العامل: ${worker.name}'),
            Text('الكود: ${worker.id}'),
            Text('الوظيفة: ${worker.job}'),
            const Divider(),
            Text('أجر اليوم: ${worker.dailyWage.toStringAsFixed(2)} جنيه'),
            Text('الإضافي: ${(overtimeHours * worker.overtimeRate).toStringAsFixed(2)} جنيه'),
            Text('السلف: ${worker.advance.toStringAsFixed(2)} جنيه'),
            Text('الخصومات: ${worker.deductions.toStringAsFixed(2)} جنيه'),
            const Divider(),
            Text('صافي المستحق: ${netToday.toStringAsFixed(2)} جنيه',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}

class SalaryPage extends StatefulWidget {
  final List<Worker> workers;
  final Map<String,Attendance> today;
  final double Function(Attendance) otHours;
  final double Function(Worker) salaryFor;
  const SalaryPage({
    super.key, required this.workers, required this.today,
    required this.otHours, required this.salaryFor
  });
  @override State<SalaryPage> createState()=>_SalaryPageState();
}

class _SalaryPageState extends State<SalaryPage> {
  int period = 1; // 1 = day 1-15, 2 = day 16-end
  DateTime month = DateTime.now();

  String get periodName => period==1 ? 'من 1 إلى 15' : 'من 16 إلى نهاية الشهر';

  int get periodStart => period==1 ? 1 : 16;
  int get periodEnd {
    if(period==1) return 15;
    return DateTime(month.year, month.month+1, 0).day;
  }

  String monthName(int m) {
    const names=['','يناير','فبراير','مارس','أبريل','مايو','يونيو',
      'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return names[m];
  }

  // This screen shows the selected payroll period. Attendance records
  // are stored by date, so the production version can aggregate all
  // dates in the selected period.
  double periodBase(Worker w) {
    // The current local record is used as a live preview; the period
    // structure is ready for daily records to be aggregated.
    final a=widget.today[w.id]??Attendance();
    return a.checkIn==null ? 0 : w.dailyWage;
  }

  double periodOT(Worker w) {
    final a=widget.today[w.id]??Attendance();
    return widget.otHours(a)*w.overtimeRate;
  }

  double net(Worker w) =>
      periodBase(w)+periodOT(w)-w.advance-w.deductions;

  @override Widget build(BuildContext c) {
    double total=0;
    for(final w in widget.workers) total+=net(w);

    return Directionality(
      textDirection:TextDirection.rtl,
      child:Scaffold(
        appBar:AppBar(
          title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('DAHAB',style:TextStyle(fontWeight:FontWeight.w800,letterSpacing:1.2)),Text('كشف الرواتب • $periodName',style:const TextStyle(fontSize:12))]),
          centerTitle:true,
        ),
        body:ListView(
          padding:const EdgeInsets.all(12),
          children:[
            Card(
              child:Padding(
                padding:const EdgeInsets.all(12),
                child:Column(children:[
                  Row(children:[
                    Expanded(
                      child:ChoiceChip(
                        label:const Text('1 - 15'),
                        selected:period==1,
                        onSelected:(_)=>setState(()=>period=1),
                      )
                    ),
                    const SizedBox(width:8),
                    Expanded(
                      child:ChoiceChip(
                        label:const Text('16 - نهاية الشهر'),
                        selected:period==2,
                        onSelected:(_)=>setState(()=>period=2),
                      )
                    ),
                  ]),
                  const SizedBox(height:10),
                  Row(
                    mainAxisAlignment:MainAxisAlignment.center,
                    children:[
                      IconButton(
                        onPressed:()=>setState(()=>month=DateTime(month.year,month.month-1,1)),
                        icon:const Icon(Icons.chevron_right),
                      ),
                      Text(
                        '${monthName(month.month)} ${month.year}',
                        style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)
                      ),
                      IconButton(
                        onPressed:()=>setState(()=>month=DateTime(month.year,month.month+1,1)),
                        icon:const Icon(Icons.chevron_left),
                      ),
                    ]
                  ),
                  Text(
                    'الفترة: ${periodStart} إلى ${periodEnd} ${monthName(month.month)}',
                    style:const TextStyle(fontWeight:FontWeight.bold)
                  ),
                  const SizedBox(height:8),
                  const Divider(),
                  const Text('إجمالي المعروض في الكشف'),
                  Text(
                    '${total.toStringAsFixed(2)} جنيه',
                    style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold)
                  ),
                ])
              )
            ),
            const SizedBox(height:5),
            ...widget.workers.map((w){
              final a=widget.today[w.id]??Attendance();
              final hours=widget.otHours(a);
              final base=periodBase(w);
              final ot=periodOT(w);
              final netValue=net(w);
              return Card(
                child:Padding(
                  padding:const EdgeInsets.all(12),
                  child:Column(
                    crossAxisAlignment:CrossAxisAlignment.stretch,
                    children:[
                      Row(children:[
                        CircleAvatar(child:Text(w.id.substring(2))),
                        const SizedBox(width:10),
                        Expanded(child:Text(
                          '${w.id} - ${w.name}',
                          style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)
                        )),
                        Text('${netValue.toStringAsFixed(2)} ج',
                          style:const TextStyle(fontWeight:FontWeight.bold))
                      ]),
                      const SizedBox(height:8),
                      Text('الفترة: $periodName'),
                      Text('الأجر: ${base.toStringAsFixed(2)} ج'),
                      Text('الإضافي: ${hours.toStringAsFixed(2)} ساعة = ${ot.toStringAsFixed(2)} ج'),
                      Text('السلفة: ${w.advance.toStringAsFixed(2)} ج'),
                      Text('الخصومات: ${w.deductions.toStringAsFixed(2)} ج'),
                      const Divider(),
                      Text(
                        'صافي المستحق: ${netValue.toStringAsFixed(2)} جنيه',
                        style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)
                      ),
                    ]
                  )
                )
              );
            })
          ]
        )
      )
    );
  }
}
