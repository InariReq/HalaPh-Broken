import 'package:flutter/material.dart';
import 'package:halaph/db/local_db.dart';
import 'package:halaph/models/plan.dart';

class DbInspectorScreen extends StatefulWidget {
  const DbInspectorScreen({Key? key}) : super(key: key);

  @override
  State<DbInspectorScreen> createState() => _DbInspectorScreenState();
}

class _DbInspectorScreenState extends State<DbInspectorScreen> {
  List<TravelPlan> _plans = [];
  List<String> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plans = await LocalDb.instance.loadPlans();
    final favs = await LocalDb.instance.loadFavorites();
    setState(() {
      _plans = plans;
      _favorites = favs;
      _loading = false;
    });
  }

  Widget _planCard(TravelPlan p) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(p.title),
        subtitle: Text('${p.startDate.toLocal()} - ${p.endDate.toLocal()}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DB Inspector'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plans (${_plans.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _plans.length,
                      itemBuilder: (ctx, i) => _planCard(_plans[i]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Favorites (${_favorites.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
    );
  }
}
