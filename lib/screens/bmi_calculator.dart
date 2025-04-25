import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/localization_service.dart';

class BMICalculatorScreen extends StatefulWidget {
  const BMICalculatorScreen({Key? key}) : super(key: key);

  @override
  State<BMICalculatorScreen> createState() => _BMICalculatorScreenState();
}

class _BMICalculatorScreenState extends State<BMICalculatorScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  double? _bmi;
  String _category = '';
  bool _isMenuOpen = false;
  bool _hasCalculated = false;

  // Firebase instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Animation controller for smooth transitions
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  void _calculateBMI({bool animate = true}) {
    double weight = double.tryParse(_weightController.text) ?? 0;
    double height = double.tryParse(_heightController.text) ?? 0;

    if (weight <= 0 || height <= 0) {
      if (animate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter valid weight and height'.tr)),
        );
      }
      return;
    }

    double bmi = weight / ((height / 100) * (height / 100));
    setState(() {
      _bmi = double.parse(bmi.toStringAsFixed(1));
      _hasCalculated = true;

      if (bmi < 16) {
        _category = 'severely_underweight';
      } else if (bmi < 18.5) {
        _category = 'underweight';
      } else if (bmi < 25) {
        _category = 'optimal';
      } else if (bmi < 30) {
        _category = 'overweight';
      } else if (bmi < 35) {
        _category = 'obese';
      } else {
        _category = 'severely_obese';
      }
    });

    // Save data to Firestore
    _saveBMIToFirestore(weight, height, _bmi!, _category);
  }

  // Save BMI record to Firestore
  Future<void> _saveBMIToFirestore(double weight, double height, double bmi, String category) async {
    try {
      // Make sure user is logged in
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('bmi_records').add({
          'userId': user.uid,
          'weight': weight,
          'height': height,
          'bmi': bmi,
          'category': category,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error saving BMI record: $e');
    }
  }

  // Show BMI history from Firestore
  void _showBMIHistory() {
    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You need to be logged in to view history'.tr)),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'bmi_history'.tr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('bmi_records')
                      .where('userId', isEqualTo: user.uid)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('${'error'.tr}: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No BMI records found'.tr));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var record = snapshot.data!.docs[index];
                        var data = record.data() as Map<String, dynamic>;

                        // Format the timestamp
                        String formattedDate = 'N/A';
                        if (data['timestamp'] != null) {
                          Timestamp timestamp = data['timestamp'] as Timestamp;
                          DateTime dateTime = timestamp.toDate();
                          formattedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}';
                        }

                        return Card(
                          child: ListTile(
                            title: Text(
                              'BMI: ${data['bmi']?.toStringAsFixed(1) ?? 'N/A'} - ${data['category'] != null ? (data['category'] as String).tr : 'N/A'}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                                '${'weight_kg'.tr}: ${data['weight']?.toString() ?? 'N/A'}, ${'height_cm'.tr}: ${data['height']?.toString() ?? 'N/A'}\n$formattedDate'
                            ),
                            trailing: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getBMICategoryColor(data['bmi'] ?? 0),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getBMICategoryColor(double bmi) {
    if (bmi < 16) {
      return Colors.blue.shade800; // Severely Underweight
    } else if (bmi < 18.5) {
      return Colors.blue.shade300; // Underweight
    } else if (bmi < 25) {
      return Colors.green; // Optimal
    } else if (bmi < 30) {
      return Colors.yellow; // Overweight
    } else if (bmi < 35) {
      return Colors.orange; // Obese
    } else {
      return Colors.red; // Severely Obese
    }
  }

  void _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate to login screen after logout
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'error'.tr} ${'logout'.tr}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        title: Text('bmi_calculator'.tr),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Container(
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.menu, color: Colors.white, size: 20),
            ),
            onPressed: () {
              setState(() {
                _isMenuOpen = !_isMenuOpen;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Weight Input
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'weight_kg'.tr,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.menu, size: 24, color: Colors.black54),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _weightController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      hintText: 'Enter weight'.tr,
                                      hintStyle: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey.shade400,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Height Input
                    Container(
                      margin: const EdgeInsets.only(bottom: 32),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'height_cm'.tr,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Row(
                              children: [
                                Transform.rotate(
                                  angle: 90 * math.pi / 180,
                                  child: const Icon(Icons.sync_alt, size: 24, color: Colors.black54),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _heightController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      hintText: 'Enter height'.tr,
                                      hintStyle: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey.shade400,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Calculate Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _calculateBMI,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Text(
                          'calculate'.tr,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // BMI Result (only shown after calculation)
                    if (_hasCalculated && _bmi != null)
                      Column(
                        children: [
                          const SizedBox(height: 32),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  _bmi!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 80,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _category.tr,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w500,
                                    color: _getBMICategoryColor(_bmi!),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // BMI Gauge with positioned needle
                                SizedBox(
                                  height: 240,
                                  width: double.infinity,
                                  child: CustomPaint(
                                    painter: CategoryBMIGaugePainter(
                                      bmi: _bmi!,
                                    ),
                                    child: Container(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Dropdown Menu (conditionally shown)
            if (_isMenuOpen)
              Positioned(
                top: 60,
                right: 16,
                child: Container(
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // History option
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: Text('bmi_history'.tr),
                        onTap: () {
                          setState(() {
                            _isMenuOpen = false;
                          });
                          _showBMIHistory();
                        },
                      ),
                      const Divider(height: 1),

                      // Language option
                      ListTile(
                        leading: const Icon(Icons.language),
                        title: Text('select_language'.tr),
                        onTap: () {
                          setState(() {
                            _isMenuOpen = false;
                          });
                          Navigator.pushNamed(context, '/language');
                        },
                      ),
                      const Divider(height: 1),

                      // Logout option
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: Text('logout'.tr, style: const TextStyle(color: Colors.red)),
                        onTap: () {
                          setState(() {
                            _isMenuOpen = false;
                          });
                          _handleLogout();
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

class CategoryBMIGaugePainter extends CustomPainter {
  final double bmi;

  CategoryBMIGaugePainter({required this.bmi});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 20);
    final radius = math.min(size.width / 2, size.height - 40);

    // Définition des couleurs
    final Paint severeUnderweightPaint = Paint()
      ..color = Colors.blue.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.butt;

    final Paint underweightPaint = Paint()
      ..color = Colors.blue.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.butt;

    final Paint optimalPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.butt;

    final Paint overweightPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.butt;

    final Paint obesePaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.butt;

    final Paint severeObesePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.butt;

    // Nouveau calcul des angles basés sur les plages BMI réelles
    const double totalBMIRange = 40.0;
    final double totalAngle = math.pi;

    // Calcul des proportions
    double severeUnderweightAngle = (16 / totalBMIRange) * totalAngle; // 0-16
    double underweightAngle = (2.5 / totalBMIRange) * totalAngle; // 16-18.5
    double optimalAngle = (6.5 / totalBMIRange) * totalAngle; // 18.5-25 (augmenté)
    double overweightAngle = (5 / totalBMIRange) * totalAngle; // 25-30
    double obeseAngle = (5 / totalBMIRange) * totalAngle; // 30-35
    double severeObeseAngle = (5 / totalBMIRange) * totalAngle; // 35-40

    // Dessin des sections
    final Rect gaugeBounds = Rect.fromCircle(center: center, radius: radius);

    // Section Severely Underweight
    canvas.drawArc(
      gaugeBounds,
      math.pi,
      severeUnderweightAngle,
      false,
      severeUnderweightPaint,
    );

    // Section Underweight (réduite)
    canvas.drawArc(
      gaugeBounds,
      math.pi + severeUnderweightAngle,
      underweightAngle,
      false,
      underweightPaint,
    );

    // Section Optimal (agrandie)
    canvas.drawArc(
      gaugeBounds,
      math.pi + severeUnderweightAngle + underweightAngle,
      optimalAngle,
      false,
      optimalPaint,
    );

    // Section Overweight
    canvas.drawArc(
      gaugeBounds,
      math.pi + severeUnderweightAngle + underweightAngle + optimalAngle,
      overweightAngle,
      false,
      overweightPaint,
    );

    // Section Obese
    canvas.drawArc(
      gaugeBounds,
      math.pi + severeUnderweightAngle + underweightAngle + optimalAngle + overweightAngle,
      obeseAngle,
      false,
      obesePaint,
    );

    // Section Severely Obese
    canvas.drawArc(
      gaugeBounds,
      math.pi + severeUnderweightAngle + underweightAngle + optimalAngle + overweightAngle + obeseAngle,
      severeObeseAngle,
      false,
      severeObesePaint,
    );

    // Lignes de séparation
    final Paint whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Dessin des lignes aux seuils exacts
    _drawDivisionLine(canvas, center, radius, math.pi, whitePaint); // 0
    _drawDivisionLine(canvas, center, radius, math.pi + severeUnderweightAngle, whitePaint); // 16
    _drawDivisionLine(canvas, center, radius, math.pi + severeUnderweightAngle + underweightAngle, whitePaint); // 18.5
    _drawDivisionLine(canvas, center, radius, math.pi + severeUnderweightAngle + underweightAngle + optimalAngle, whitePaint); // 25
    _drawDivisionLine(canvas, center, radius, math.pi + severeUnderweightAngle + underweightAngle + optimalAngle + overweightAngle, whitePaint); // 30
    _drawDivisionLine(canvas, center, radius, math.pi + severeUnderweightAngle + underweightAngle + optimalAngle + overweightAngle + obeseAngle, whitePaint); // 35
    _drawDivisionLine(canvas, center, radius, math.pi + totalAngle, whitePaint); // 40

    // Étiquettes BMI
    final List<String> bmiValues = ["0", "16", "18.5", "25", "30", "35", "40"];
    final List<double> labelAngles = [
      math.pi,
      math.pi + severeUnderweightAngle,
      math.pi + severeUnderweightAngle + underweightAngle,
      math.pi + severeUnderweightAngle + underweightAngle + optimalAngle,
      math.pi + severeUnderweightAngle + underweightAngle + optimalAngle + overweightAngle,
      math.pi + severeUnderweightAngle + underweightAngle + optimalAngle + overweightAngle + obeseAngle,
      math.pi + totalAngle
    ];

    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < bmiValues.length; i++) {
      _drawBMILabel(canvas, center, radius, labelAngles[i], bmiValues[i], textPainter);
    }

    // Calcul de l'aiguille
    double needleAngle = math.pi;
    if (bmi < 16) {
      needleAngle += (bmi / 16) * severeUnderweightAngle;
    } else if (bmi < 18.5) {
      needleAngle += severeUnderweightAngle + ((bmi - 16) / 2.5) * underweightAngle;
    } else if (bmi < 25) {
      needleAngle += severeUnderweightAngle + underweightAngle + ((bmi - 18.5) / 6.5) * optimalAngle;
    } else if (bmi < 30) {
      needleAngle += severeUnderweightAngle + underweightAngle + optimalAngle + ((bmi - 25) / 5) * overweightAngle;
    } else if (bmi < 35) {
      needleAngle += severeUnderweightAngle + underweightAngle + optimalAngle + overweightAngle + ((bmi - 30) / 5) * obeseAngle;
    } else {
      needleAngle += severeUnderweightAngle + underweightAngle + optimalAngle + overweightAngle + obeseAngle + ((bmi - 35) / 5) * severeObeseAngle;
    }

    // Dessin de l'aiguille
    final double needleLength = radius - 10;
    final Offset needleEnd = Offset(
      center.dx + math.cos(needleAngle) * needleLength,
      center.dy + math.sin(needleAngle) * needleLength,
    );
    final Paint needlePaint = Paint()
      ..color = const Color(0xFF2B4B81)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(center, needleEnd, needlePaint);

    // Point pivot
    canvas.drawCircle(center, 10, Paint()..color = const Color(0xFF2B4B81));
  }

  void _drawDivisionLine(Canvas canvas, Offset center, double radius, double angle, Paint paint) {
    final double lineX1 = center.dx + (radius - 15) * math.cos(angle);
    final double lineY1 = center.dy + (radius - 15) * math.sin(angle);
    final double lineX2 = center.dx + (radius + 15) * math.cos(angle);
    final double lineY2 = center.dy + (radius + 15) * math.sin(angle);
    canvas.drawLine(Offset(lineX1, lineY1), Offset(lineX2, lineY2), paint);
  }

  void _drawBMILabel(Canvas canvas, Offset center, double radius, double angle, String text, TextPainter textPainter) {
    const double labelOffset = 25;
    final double labelX = center.dx + (radius + labelOffset) * math.cos(angle);
    final double labelY = center.dy + (radius + labelOffset) * math.sin(angle);
    textPainter.text = TextSpan(
      text: text,
      style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(labelX - textPainter.width / 2, labelY - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(CategoryBMIGaugePainter oldDelegate) => oldDelegate.bmi != bmi;
}