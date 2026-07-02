import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'screens/home_screen.dart';
import 'services/api_client.dart';

Future<void> main() async {
  // O endereço do backend é carregado de assets/config.json.
  // Copie assets/config.example.json para assets/config.json e edite.
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.init();
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
  /// Passe `null` para voltar a usar o valor de `assets/config.json`.
  static void setBaseUrl(String? url) {
    ApiClient.baseUrl = url;
  }
}
