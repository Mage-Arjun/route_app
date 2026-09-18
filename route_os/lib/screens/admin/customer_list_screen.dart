import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/customer.dart';
import 'customer_form_screen.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  List<Customer> _customers = [];
  bool _loading = true;
  String _search = '';
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final customers = await api.getCustomers(
        search: _search,
        customerType: _typeFilter,
      );
      setState(() {
        _customers = customers;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              setState(() => _typeFilter = v == 'all' ? null : v);
              _loadCustomers();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('All Types')),
              const PopupMenuItem(value: 'retail', child: Text('Retail')),
              const PopupMenuItem(value: 'wholesale', child: Text('Wholesale')),
              const PopupMenuItem(value: 'hotel', child: Text('Hotel')),
              const PopupMenuItem(value: 'pharmacy', child: Text('Pharmacy')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
          );
          if (result == true) _loadCustomers();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) {
                _search = v;
                _loadCustomers();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                ? const Center(child: Text('No customers found'))
                : RefreshIndicator(
                    onRefresh: _loadCustomers,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _customers.length,
                      itemBuilder: (context, index) =>
                          _customerTile(_customers[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _customerTile(Customer customer) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerFormScreen(customer: customer),
            ),
          );
          if (result == true) _loadCustomers();
        },
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _typeColor(customer.customerType).withOpacity(0.1),
            child: Icon(
              _typeIcon(customer.customerType),
              color: _typeColor(customer.customerType),
              size: 20,
            ),
          ),
          title: Text(
            customer.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            customer.address ?? customer.typeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _typeColor(customer.customerType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  customer.typeLabel,
                  style: TextStyle(
                    color: _typeColor(customer.customerType),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (customer.phone != null) ...[
                const SizedBox(height: 4),
                Text(
                  customer.phone!,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'retail':
        return AppTheme.info;
      case 'wholesale':
        return AppTheme.primary;
      case 'hotel':
        return AppTheme.accent;
      case 'pharmacy':
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'retail':
        return Icons.store;
      case 'wholesale':
        return Icons.warehouse;
      case 'hotel':
        return Icons.hotel;
      case 'pharmacy':
        return Icons.local_pharmacy;
      default:
        return Icons.business;
    }
  }
}
