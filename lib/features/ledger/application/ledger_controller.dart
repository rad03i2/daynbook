import 'package:flutter/foundation.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/ledger_entry.dart';
import '../../../data/local/app_database.dart';

class LedgerController extends ChangeNotifier {
  LedgerController({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  List<CustomerAccount> _customers = const [];
  List<LedgerEntry> _entries = const [];
  CustomerAccount? _selectedCustomer;
  bool _isLoading = false;
  String _search = '';
  Object? _lastError;

  List<CustomerAccount> get customers => _customers;
  List<LedgerEntry> get entries => _entries;
  CustomerAccount? get selectedCustomer => _selectedCustomer;
  bool get isLoading => _isLoading;
  String get search => _search;
  Object? get lastError => _lastError;

  int get totalOutstanding => _customers.fold<int>(
        0,
        (sum, customer) => sum + (customer.balance > 0 ? customer.balance : 0),
      );

  Future<void> initialize() async {
    await loadCustomers();
  }

  Future<void> loadCustomers({String? search}) async {
    _isLoading = true;
    _lastError = null;
    if (search != null) _search = search;
    notifyListeners();

    try {
      final previousId = _selectedCustomer?.id;
      _customers = await _database.getCustomers(search: _search);
      if (previousId != null) {
        final matches = _customers.where((customer) => customer.id == previousId);
        _selectedCustomer = matches.isEmpty ? null : matches.first;
      }
    } catch (error) {
      _lastError = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectCustomer(CustomerAccount customer) async {
    _selectedCustomer = customer;
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      _entries = await _database.getEntries(customer.id);
    } catch (error) {
      _lastError = error;
      _entries = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSelection() {
    _selectedCustomer = null;
    _entries = const [];
    notifyListeners();
  }

  Future<void> createCustomer({
    required String name,
    String? phone,
    String? notes,
  }) async {
    _lastError = null;
    try {
      final customer = await _database.createCustomer(
        name: name,
        phone: phone,
        notes: notes,
      );
      await loadCustomers();
      await selectCustomer(customer);
    } catch (error) {
      _lastError = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addEntry({
    required LedgerEntryType type,
    required int amount,
    String? description,
    String? notes,
  }) async {
    final customer = _selectedCustomer;
    if (customer == null) throw StateError('No customer selected');

    _lastError = null;
    try {
      await _database.addEntry(
        customerId: customer.id,
        type: type,
        amount: amount,
        description: description,
        notes: notes,
      );
      await loadCustomers();
      final refreshed = _customers.where((item) => item.id == customer.id);
      if (refreshed.isNotEmpty) {
        await selectCustomer(refreshed.first);
      }
    } catch (error) {
      _lastError = error;
      notifyListeners();
      rethrow;
    }
  }
}
