import 'dart:math' as math;
import 'package:flutter/material.dart';

const _orange = Color(0xFFFF6718);

class SplashGate extends StatefulWidget {
  final Widget child;
  const SplashGate({super.key, required this.child});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) setState(() {});
      });
      controller.forward();
      if (MediaQuery.disableAnimationsOf(context)) controller.value = 1;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller.isCompleted) return widget.child;
    return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final progress = Curves.easeOutCubic.transform(controller.value);
            return Opacity(
                opacity: (controller.value * 6).clamp(0, 1),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                      width: 260,
                      height: 260,
                      child: Stack(alignment: Alignment.center, children: [
                        Transform.rotate(
                            angle: progress * math.pi * 2,
                            child: SizedBox(
                                width: 218,
                                height: 218,
                                child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 2,
                                    color: _orange,
                                    backgroundColor: Colors.black))),
                        Transform.scale(
                            scale: 0.6 + 0.4 * progress,
                            child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                    color: _orange,
                                    borderRadius: BorderRadius.circular(32)),
                                child: const Icon(Icons.restaurant,
                                    size: 62, color: Colors.black))),
                        ...List.generate(4, (i) {
                          final angle =
                              i * math.pi / 2 + progress * math.pi / 2;
                          return Transform.translate(
                              offset: Offset(
                                  math.cos(angle) * 108, math.sin(angle) * 108),
                              child: Container(
                                  padding: const EdgeInsets.all(10),
                                  color: Colors.black,
                                  child: Icon(
                                      [
                                        Icons.coffee,
                                        Icons.bakery_dining,
                                        Icons.local_drink,
                                        Icons.ramen_dining
                                      ][i],
                                      color: _orange,
                                      size: 30)));
                        }),
                      ])),
                  const SizedBox(height: 30),
                  const Text('AMEXA',
                      style: TextStyle(
                          color: _orange,
                          fontSize: 30,
                          letterSpacing: 10,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  const Icon(Icons.more_horiz, color: _orange, size: 36),
                ]));
          },
        )));
  }
}
