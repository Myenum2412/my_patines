import 'package:flutter/material.dart';

import '../main.dart' show LoginPage;

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({
    super.key,
    this.userName,
    this.email,
  });

  final String? userName;
  final String? email;

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  int _index = 0;

  static const _titles = ['Home', 'Medical Record', 'Billing', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomeTab(userName: widget.userName),
      const _PlaceholderTab(
        icon: Icons.folder_shared_outlined,
        title: 'Medical Record',
        description: 'Your medical records will appear here.',
      ),
      const _PlaceholderTab(
        icon: Icons.receipt_long_outlined,
        title: 'Billing',
        description: 'Your billing details and invoices will appear here.',
      ),
      _ProfileTab(userName: widget.userName, email: widget.email),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_shared_outlined),
            selectedIcon: Icon(Icons.folder_shared),
            label: 'Medical Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Billing',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    final name = (userName != null && userName!.trim().isNotEmpty)
        ? userName!.trim()
        : 'Patient';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Welcome, $name',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Patient portal access',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 20),
        _InfoCard(
          icon: Icons.calendar_today_outlined,
          color: const Color(0xFF2196F3),
          title: 'Appointments',
          subtitle: 'View and manage your upcoming visits.',
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.folder_shared_outlined,
          color: const Color(0xFF0EA5E9),
          title: 'Medical Records',
          subtitle: 'Access your reports and prescriptions.',
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.receipt_long_outlined,
          color: const Color(0xFF14B8A6),
          title: 'Billing',
          subtitle: 'Check invoices and payment history.',
        ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({this.userName, this.email});

  final String? userName;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final displayName = (userName != null && userName!.trim().isNotEmpty)
        ? userName!.trim()
        : 'Patient';
    final displayEmail = (email != null && email!.trim().isNotEmpty)
        ? email!.trim()
        : 'Not available';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFFDBEAFE),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            displayName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            displayEmail,
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.badge_outlined),
                title: Text('Account type'),
                subtitle: Text('Patient'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFF2196F3)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
