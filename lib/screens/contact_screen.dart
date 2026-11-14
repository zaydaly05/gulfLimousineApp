import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/locale_service.dart';
import '../theme/app_theme.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static const _phone = '+201001116666';
  static const _email = 'info@gulflimousine.com';
  static const _whatsapp = '+201001116666';

  Future<void> _launch(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch $uri: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Premium Header
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            stretch: true,
            backgroundColor: AppTheme.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                context.t('contactUs'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1.2,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF000000), Color(0xFF222222)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 60,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          size: 70,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                  ),
                  // Decorative elements
                  Positioned(
                    bottom: -20,
                    right: -20,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Message
                  Text(
                    context.t('weLoveHear'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.t('contactIntro'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Quick Actions Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _ModernContactCard(
                        icon: Icons.chat_bubble_rounded,
                        label: context.t('whatsapp'),
                        color: const Color(0xFF25D366),
                        onTap: () =>
                            _launch(Uri.parse('https://wa.me/$_whatsapp')),
                      ),
                      _ModernContactCard(
                        icon: Icons.call_rounded,
                        label: context.t('call'),
                        color: Colors.blue.shade600,
                        onTap: () => _launch(Uri.parse('tel:$_phone')),
                      ),
                      _ModernContactCard(
                        icon: Icons.alternate_email_rounded,
                        label: context.t('email'),
                        color: AppTheme.accent,
                        onTap: () => _launch(Uri.parse('mailto:$_email')),
                      ),
                      _ModernContactCard(
                        icon: Icons.location_on_rounded,
                        label: context.t('location'),
                        color: Colors.red.shade400,
                        onTap: () => _launch(
                          Uri.parse('https://maps.google.com/?q=Cairo,Egypt'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Support Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppTheme.accent,
                          radius: 24,
                          child: Icon(
                            Icons.flash_on_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '24/7 Premium Support',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Our concierge team is ready to assist you.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Info Section
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_filled_rounded,
                        color: AppTheme.accent,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        context.t('openingHours'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Text(
                      context.t('openingHoursValue'),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Divider(thickness: 1.2),
                  ),

                  // FAQs Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.t('faqs'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Icon(
                        Icons.help_outline_rounded,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _StyledFaqTile(
                    question: context.t('faqPickup'),
                    answer: context.t('faqPickupAns'),
                  ),
                  _StyledFaqTile(
                    question: context.t('faqInsurance'),
                    answer: context.t('faqInsuranceAns'),
                  ),
                  _StyledFaqTile(
                    question: context.t('faqDocs'),
                    answer: context.t('faqDocsAns'),
                  ),

                  const SizedBox(height: 50),

                  // Social Footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          context.t('followUs').toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ModernSocialIcon(
                              icon: Icons.facebook_rounded,
                              onTap: () {},
                            ),
                            const SizedBox(width: 20),
                            _ModernSocialIcon(
                              icon: Icons.camera_alt_rounded,
                              onTap: () {},
                            ),
                            const SizedBox(width: 20),
                            _ModernSocialIcon(
                              icon: Icons.public_rounded,
                              onTap: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ModernContactCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyledFaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _StyledFaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedAlignment: Alignment.topLeft,
        textColor: AppTheme.accent,
        iconColor: AppTheme.accent,
        children: [
          Text(
            answer,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.6,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernSocialIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ModernSocialIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: Colors.black87, size: 24),
      ),
    );
  }
}
