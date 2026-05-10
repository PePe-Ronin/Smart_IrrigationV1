import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:smart_irrigation/new_device.dart';

class IrrigationDashboard extends StatelessWidget {
  const IrrigationDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey[100],

        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Smart Irrigation",
                style: TextStyle(color: Colors.black, fontSize: 18),
              ),
              Text(
                "Dashboard",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),

        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.green,
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () {
            _showAddZoneDialog(context);
          },
        ),

        body: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            children: [
              /// STATUS CARDS
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("zones")
                    .snapshots(),

                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var zones = snapshot.data!.docs;

                  int totalZones = zones.length;

                  int activeZones = zones.where((zone) {
                    return zone["status"].toString().toUpperCase() == "ON";
                  }).length;

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),

                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,

                    children: [
                      StatusCard(
                        icon: Icons.power_settings_new,
                        title: "Active Zones",
                        value: "$activeZones / $totalZones",
                      ),

                      StatusCard(
                        icon: Icons.water_drop,
                        title: "Avg Moisture",
                        value: _calculateAverageMoisture(zones),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              /// TITLE
              Row(
                children: const [
                  Icon(Icons.grass, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    "Irrigation Zones",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              /// ZONES LIST
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("zones")
                      .snapshots(),

                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text("No irrigation zones found"),
                      );
                    }

                    var zones = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: zones.length,

                      itemBuilder: (context, index) {
                        var zone = zones[index];
                        String docId = zone.id;

                        return Slidable(
                          key: ValueKey(docId),

                          /// DELETE
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (context) async {
                                  await FirebaseFirestore.instance
                                      .collection("zones")
                                      .doc(docId)
                                      .delete();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Zone deleted"),
                                    ),
                                  );
                                },

                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                icon: Icons.delete,
                                label: "Delete",
                              ),
                            ],
                          ),

                          /// EDIT
                          startActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (context) {
                                  _showEditDialog(context, docId, zone);
                                },

                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                icon: Icons.edit,
                                label: "Edit",
                              ),
                            ],
                          ),

                          child: ZoneCard(
                            title: zone["title"] ?? "No Title",
                            size: zone["size"] ?? "Unknown",
                            moisture: (zone["moisture"] as num).toDouble(),
                            status: zone["status"] ?? "OFF",
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ================= ADD ZONE =================

void _showAddZoneDialog(BuildContext context) {
  TextEditingController titleController = TextEditingController();

  TextEditingController deviceController = TextEditingController();

  TextEditingController sizeController = TextEditingController();

  showDialog(
    context: context,

    builder: (context) {
      return AlertDialog(
        title: const Text("Add New Zone"),

        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Zone Title"),
              ),

              TextField(
                controller: sizeController,
                decoration: const InputDecoration(labelText: "Zone Size"),
              ),

              TextField(
                controller: deviceController,
                decoration: const InputDecoration(labelText: "Device ID"),
              ),

              const SizedBox(height: 10),

              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WifiProvisionPage(),
                    ),
                  );
                },

                child: const Text("Connect Device"),
              ),
            ],
          ),
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },

            child: const Text("Cancel"),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),

            onPressed: () async {
              String title = titleController.text.trim();
              String size = sizeController.text.trim();
              String deviceId = deviceController.text.trim();

              if (title.isEmpty || size.isEmpty || deviceId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Fill all fields")),
                );

                return;
              }

              await FirebaseFirestore.instance
                  .collection("zones")
                  .doc(deviceId)
                  .set({
                    "title": title,
                    "size": size,
                    "deviceId": deviceId,
                    "moisture": 0.0,
                    "status": "OFF",
                    "created_at": FieldValue.serverTimestamp(),
                  });

              Navigator.pop(context);

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Zone Added")));
            },

            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
}

/// ================= EDIT ZONE =================

void _showEditDialog(
  BuildContext context,
  String docId,
  QueryDocumentSnapshot zone,
) {
  TextEditingController titleController = TextEditingController(
    text: zone["title"],
  );

  TextEditingController sizeController = TextEditingController(
    text: zone["size"],
  );

  showDialog(
    context: context,

    builder: (context) {
      return AlertDialog(
        title: const Text("Edit Zone"),

        content: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Title"),
            ),

            TextField(
              controller: sizeController,
              decoration: const InputDecoration(labelText: "Size"),
            ),
          ],
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },

            child: const Text("Cancel"),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),

            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection("zones")
                  .doc(docId)
                  .update({
                    "title": titleController.text,
                    "size": sizeController.text,
                  });

              Navigator.pop(context);
            },

            child: const Text("Update", style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
}

/// ================= STATUS CARD =================

class StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const StatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),

      padding: const EdgeInsets.all(14),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: Colors.green, size: 30),

          const Spacer(),

          Text(title, style: const TextStyle(color: Colors.grey)),

          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// ================= ZONE CARD =================

class ZoneCard extends StatelessWidget {
  final String title;
  final String size;
  final double moisture;
  final String status;

  const ZoneCard({
    super.key,
    required this.title,
    required this.size,
    required this.moisture,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(14),

      decoration: cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          Text(size, style: const TextStyle(color: Colors.grey)),

          const SizedBox(height: 10),

          LinearProgressIndicator(
            value: moisture.clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
          ),

          const SizedBox(height: 8),

          Text("Soil Moisture ${(moisture).toInt()}%"),

          const SizedBox(height: 4),

          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black),

              children: [
                const TextSpan(text: "Pump Status: "),

                TextSpan(
                  text: status,

                  style: TextStyle(
                    color: status.toUpperCase() == "ON"
                        ? Colors.green
                        : Colors.red,

                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ================= AVG MOISTURE =================

String _calculateAverageMoisture(List<QueryDocumentSnapshot> zones) {
  if (zones.isEmpty) {
    return "0%";
  }

  double total = 0;

  for (var zone in zones) {
    total += (zone["moisture"] as num).toDouble();
  }

  double avg = total / zones.length;

  return "${(avg * 100).toInt()}%";
}

/// ================= CARD STYLE =================

BoxDecoration cardDecoration() {
  return BoxDecoration(
    color: Colors.white,

    borderRadius: BorderRadius.circular(16),

    boxShadow: [
      BoxShadow(
        color: Colors.grey.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
