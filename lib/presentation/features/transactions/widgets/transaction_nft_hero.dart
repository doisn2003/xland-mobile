import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Local vector artwork supplied for the transaction tab. No commerce actions.
class TransactionNftHero extends StatelessWidget {
  const TransactionNftHero({super.key, required this.active});

  static const backgroundColor = Color(0xFF031B1B);
  final bool active;

  @override
  Widget build(BuildContext context) {
    final animate =
        active &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);

    return ColoredBox(
      color: backgroundColor,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                fit: StackFit.expand,
                children: [
                  ExcludeSemantics(
                    child: RepaintBoundary(
                      child: Lottie.asset(
                        'assets/animations/xland-nft.json',
                        fit: BoxFit.contain,
                        animate: animate,
                        repeat: true,
                        frameRate: FrameRate.composition,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset(
                              'assets/animations/xland-nft-poster.png',
                              fit: BoxFit.contain,
                            ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: constraints.maxHeight * .08,
                    left: 24,
                    right: 24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'GIAO DỊCH NFT',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(0xFF9ABDA6),
                                letterSpacing: 2.2,
                              ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tính năng sắp ra mắt',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFECF3DF),
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
