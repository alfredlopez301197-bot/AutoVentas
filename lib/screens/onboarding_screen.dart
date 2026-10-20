import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Textos e íconos adaptados para Panda
  final List<Map<String, String>> _onboardingData = [
    {
      "title": "Control de Ventas Panda",
      "description": "Lleva el registro exacto de tus pedidos y objetivos de venta al instante.",
    },
    {
      "title": "Gestión de Clientes",
      "description": "Administra tus rutas y mantén la información de tus clientes siempre actualizada.",
    },
    {
      "title": "Sincronización en Tiempo Real",
      "description": "Toda tu actividad se sincroniza con la base de datos de manera automática.",
    }
  ];

  void _goToLogin() {
    // Al terminar o saltar, va a la pantalla de Auth
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _goToLogin,
            child: const Text(
              'Saltar',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (value) {
                setState(() {
                  _currentPage = value;
                });
              },
              itemCount: _onboardingData.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIcon(index),
                          size: 80,
                          color: const Color(0xFFD4AF37), // Mismo tono dorado de tu imagen
                        ),
                      ),
                      const SizedBox(height: 50),
                      Text(
                        _onboardingData[index]["title"]!,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _onboardingData[index]["description"]!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Puntos indicadores de página
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _onboardingData.length,
              (index) => _buildDot(index: index),
            ),
          ),
          const SizedBox(height: 40),
          
          // Botón Siguiente / Empezar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37), // Tono dorado de la app
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  if (_currentPage == _onboardingData.length - 1) {
                    _goToLogin();
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeIn,
                    );
                  }
                },
                child: Text(
                  _currentPage == _onboardingData.length - 1 ? 'Empezar' : 'Siguiente',
                  style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Define los íconos para cada página
  IconData _getIcon(int index) {
    switch (index) {
      case 0:
        return Icons.shopping_bag_outlined;
      case 1:
        return Icons.people_alt_outlined;
      case 2:
        return Icons.sync_rounded;
      default:
        return Icons.info_outline;
    }
  }

  // Constructor de los puntos
  Widget _buildDot({required int index}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? const Color(0xFFD4AF37) : Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
