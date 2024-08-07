import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ExpenseTracker/widgets/new_expense.dart';
import 'package:ExpenseTracker/widgets/expenses_list/expenses_list.dart';
import 'package:ExpenseTracker/models/expense.dart';
import 'package:ExpenseTracker/widgets/chart/chart.dart';

class Expenses extends StatefulWidget {
  const Expenses({super.key});

  @override
  State<Expenses> createState() {
    return _ExpensesState();
  }
}

class _ExpensesState extends State<Expenses> {
  final List<Expense> _registeredExpenses = [];

  @override
  void initState() {
    _display();
    super.initState();
  }

  void _display() async {
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('user').get();

      List<Expense> newExpenses = querySnapshot.docs.map((doc) {
        Map<String, dynamic> val = doc.data() as Map<String, dynamic>;

        final obT = val['title'] as String;
        final obAmount =
            (val['amount'] as num).toDouble(); // Ensure it's a double
        final obDate = (val['date'] as Timestamp)
            .toDate(); // Convert Firestore Timestamp to DateTime

        // Safely parse the category from Firestore
        final categoryString = val['category'] as String;
        final obCat = Category.values.firstWhere(
          (e) => e.toString() == categoryString,
          orElse: () => Category.unknown, // Default value in case of no match
        );

        return Expense(
          title: obT,
          amount: obAmount,
          date: obDate,
          category: obCat,
        );
      }).toList();

      setState(() {
        _registeredExpenses.addAll(newExpenses);
      });
    } catch (e) {
      print('Error fetching documents: $e');
    }
  }

  void _openAddExpenseOverlay() {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (ctx) => NewExpense(onAddExpense: _addExpense),
    );
  }

  void _addExpense(Expense expense) async {
    setState(() {
      _registeredExpenses.add(expense);
    });
  }

  void _removeExpense(Expense expense) async {
    for (Expense exp in _registeredExpenses) {
      if (exp.id == expense.id) {
        await FirebaseFirestore.instance
            .collection('user')
            .doc(exp.id)
            .delete();
        print("!!FOUND");
      } else {
        print("!!NOT FOUND!!");
      }
    }

    final expenseIndex = _registeredExpenses.indexOf(expense);

    setState(() {
      _registeredExpenses.remove(expense);
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: const Text('Expense deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await FirebaseFirestore.instance
                .collection('user')
                .doc(expense.id)
                .set({
              'title': expense.title,
              'amount': expense.amount,
              'date': expense.date,
              'category': expense.category.name,
            });
            setState(() {
              _registeredExpenses.insert(expenseIndex, expense);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget mainContent = const Center(
      child: Text('No expenses found. Start adding some!'),
    );

    if (_registeredExpenses.isNotEmpty) {
      mainContent = ExpensesList(
        expenses: _registeredExpenses,
        onRemoveExpense: _removeExpense,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ExpenseTracker'),
        actions: [
          IconButton(
            onPressed: _openAddExpenseOverlay,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Chart(expenses: _registeredExpenses),
          Expanded(
            child: mainContent,
          ),
        ],
      ),
    );
  }
}
