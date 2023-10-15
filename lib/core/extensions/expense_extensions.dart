import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:paisa/core/enum/transaction_type.dart';
import 'package:paisa/core/extensions/time_extension.dart';
import 'package:paisa/features/category/domain/entities/category.dart';
import 'package:paisa/features/transaction/data/model/transaction_model.dart';
import 'package:paisa/features/transaction/data/model/search_query.dart';
import 'package:paisa/features/transaction/domain/entities/transaction.dart';

import '../../features/home/presentation/bloc/home/home_bloc.dart';

extension ExpenseModelBoxMapping on Box<TransactionModel> {
  List<TransactionModel> get expenses =>
      values.sorted((a, b) => b.time!.compareTo(a.time!));

  List<TransactionModel> expensesFromAccountId(int accountId) =>
      expenses.where((element) => element.accountId == accountId).toList();

  List<TransactionEntity> get toEntities => values
      .map((expenseModel) => expenseModel.toEntity())
      .sorted((a, b) => b.time!.compareTo(a.time!));

  List<TransactionModel> isFilterTimeBetween(DateTimeRange range) => values
      .where((element) => element.time!.isAfterBeforeTime(range))
      .toList();

  Iterable<TransactionModel> get expenseList =>
      values.where((element) => element.type == TransactionType.expense);

  Iterable<TransactionModel> get incomeList =>
      values.where((element) => element.type == TransactionType.income);

  double get totalExpense => expenseList.map((e) => e.currency).fold<double>(
      0, (previousValue, element) => previousValue + (element ?? 0));

  double get totalIncome => incomeList.map((e) => e.currency).fold<double>(
      0, (previousValue, element) => previousValue + (element ?? 0));

  Iterable<TransactionModel> search(SearchQuery query) {
    return values.where((element) {
      final String text = query.query?.toLowerCase() ?? '';
      final String desc = (element.description ?? '').toLowerCase();
      final String name = (element.name ?? '').toLowerCase();
      final List<int> accounts = query.accounts ?? [];
      final List<int> categories = query.categories ?? [];
      return (name.contains(text) || desc.contains(text)) &&
          (accounts.contains(element.accountId) &&
              categories.contains(element.categoryId));
    });
  }
}

extension ExpenseModelHelper on TransactionModel {
  TransactionEntity toEntity() => TransactionEntity(
        name: name,
        currency: currency,
        time: time,
        categoryId: categoryId,
        accountId: accountId,
        type: type,
        description: description,
        superId: superId,
      );
}

extension ExpenseModelsHelper on Iterable<TransactionModel> {
  List<Map<String, dynamic>> toJson() {
    return map((e) => e.toJson()).toList();
  }

  List<TransactionEntity> toEntities() {
    return map((expenseModel) => expenseModel.toEntity())
        .sorted((a, b) => b.time!.compareTo(a.time!));
  }

  List<TransactionEntity> budgetOverView(TransactionType transactionType) =>
      sorted((a, b) => b.time!.compareTo(a.time!))
          .where((element) => element.type == transactionType)
          .toEntities();
}

extension ExpensesHelper on Iterable<TransactionEntity> {
  List<TransactionEntity> sortByTime() =>
      sorted((a, b) => b.time!.compareTo(a.time!));

  List<TransactionEntity> get expenses => sortByTime();

  List<TransactionEntity> get expenseList =>
      where((element) => element.type == TransactionType.expense).toList();

  List<TransactionEntity> get incomeList =>
      where((element) => element.type == TransactionType.income).toList();

  List<TransactionEntity> isFilterTimeBetween(DateTimeRange range) =>
      where((element) => element.time!.isAfterBeforeTime(range)).toList();

  List<TransactionEntity> transactionsForCid(int cid) =>
      where((element) => element.categoryId! == cid).toList();

  double get filterTotal => fold<double>(0, (previousValue, element) {
        if (element.type == TransactionType.expense) {
          return previousValue - (element.currency ?? 0);
        } else if (element.type == TransactionType.income) {
          return previousValue + (element.currency ?? 0);
        } else {
          return previousValue;
        }
      });

  double fullTotal(BuildContext? context) =>
      totalIncome(context) - totalExpense(context);

  double totalExpense(BuildContext? context) => expenseList.fold<double>(
        0,
        (previousValue, element) {
          if (context != null) {
            CategoryEntity? category = BlocProvider.of<HomeBloc>(context)
                .fetchCategoryFromId(element.categoryId!);
            if (category?.isDefault ?? false) {
              return previousValue;
            }
          }
          return previousValue + (element.currency ?? 0);
        },
      );

  double totalIncome(BuildContext? context) => incomeList.fold<double>(
        0,
        (previousValue, element) {
          if (context != null) {
            CategoryEntity? category = BlocProvider.of<HomeBloc>(context)
                .fetchCategoryFromId(element.categoryId!);
            if (category?.isDefault ?? false) {
              return previousValue;
            }
          }
          return previousValue + (element.currency ?? 0);
        },
      );

  double get total => map((e) => e.currency).fold<double>(
      0, (previousValue, element) => previousValue + (element ?? 0));

  double thisMonthExpense(BuildContext? context) =>
      thisMonthExpensesList(context)
          .map((e) => e.currency)
          .fold<double>(
              0, (previousValue, element) => previousValue + (element ?? 0));

  List<TransactionEntity> thisMonthExpensesList(BuildContext? context) =>
      where(
            (element) {
          if (context != null) {
            CategoryEntity? category = BlocProvider.of<HomeBloc>(context)
                .fetchCategoryFromId(element.categoryId!);
            if (category?.isDefault ?? false) {
              return false;
            }
          }
          return element.type == TransactionType.expense;
        },
      )
          .where((element) =>
              element.time?.month == DateTime.now().month &&
              element.time?.year == DateTime.now().year)
          .toList();

  List<double> expenseDoubleList(BuildContext? context) =>
      thisMonthExpensesList(context).map((element) => (element.currency ?? 0)).toList();

  List<TransactionEntity> thisMonthIncomeList(BuildContext? context) => where(
        (element) {
          if (context != null) {
            CategoryEntity? category = BlocProvider.of<HomeBloc>(context)
                .fetchCategoryFromId(element.categoryId!);
            if (category?.isDefault ?? false) {
              return false;
            }
          }
          return element.type == TransactionType.income;
        },
      )
          .where((element) =>
              element.time?.month == DateTime.now().month &&
              element.time?.year == DateTime.now().year)
          .toList();

  List<double> incomeDoubleList(BuildContext? context) =>
      thisMonthIncomeList(context).map((element) => (element.currency ?? 0)).toList();

  double thisMonthIncome(BuildContext? context) =>
      thisMonthIncomeList(context).map((e) => e.currency).fold<double>(
          0, (previousValue, element) => previousValue + (element ?? 0));
}

extension TransactionHelper on TransactionEntity {}
