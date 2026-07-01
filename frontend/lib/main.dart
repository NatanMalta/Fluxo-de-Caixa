import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'screens/home_screen.dart';
import 'services/api_client.dart';

void main() {
  // No Android emulador, o host é acessado por 10.0.2.2.
  // No Android device físico via Wi-Fi, configure para o IP do PC.
  // No Web rodando no mesmo PC, localhost:5000 funciona.
  // O usuário pode sobrescrever isto na tela de configurações futuramente.
  runApp(const FluxoCaixaApp());
}

final currencyFormat = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 2,
);
final dateFormat = DateFormat('dd/MM/yyyy');

class FluxoCaixaApp extends StatelessWidget {
  const FluxoCaixaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fluxo de Caixa',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ApiBaseUrlSetting {
  /// Permite ajustar o endereço do backend em tempo de execução.
  /// O app é single-user; não há settings persistidos nesta versão.
  static void setBaseUrl(String url) {
    ApiClient.baseUrl = url;
  }
}
