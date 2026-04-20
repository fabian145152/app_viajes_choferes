import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:async';

void main() => runApp(const MaterialApp(home: BotonCoordenadas()));

class BotonCoordenadas extends StatefulWidget {
  const BotonCoordenadas({super.key});

  @override
  State<BotonCoordenadas> createState() => _BotonCoordenadasState();
}

class _BotonCoordenadasState extends State<BotonCoordenadas> {
  bool estaActivo = false;
  Timer? _timer;
  // Controlador para el ID del usuario
  final TextEditingController _idController = TextEditingController(text: "Chofer_01");

  // Función genérica que acepta el estado ('activo' o 'inactivo')
  Future<void> enviarDatos(String status) async {
    try {
      // Obtenemos la posición actual
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );

      final url = Uri.parse('http://192.168.0.225/app_viajes/backend/php/01_mapeo/recibir.php');

      final respuesta = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'lat': position.latitude,
          'lng': position.longitude,
          'status': status,
          'usuario_id': _idController.text
        }),
      ).timeout(const Duration(seconds: 4)); // Timeout para evitar que se cuelgue

      print('Enviado ($status) - ID: ${_idController.text} - Status: ${respuesta.statusCode}');
    } catch (e) {
      print('Error al enviar ($status): $e');
    }
  }

  // Maneja el inicio del timer o la ráfaga de cierre
  void controlarCiclo(bool activado) async {
    if (activado) {
      // 1. Iniciar: Enviamos el primero inmediatamente
      enviarDatos('activo');
      // 2. Configuramos el envío recurrente cada 5 segundos
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        enviarDatos('activo');
      });
    } else {
      // 1. Detener: Cancelamos el timer de inmediato
      _timer?.cancel();

      print("Iniciando ráfaga de cierre (3 envíos)...");
      // 2. Enviamos 3 veces el estatus 'inactivo' para asegurar recepción
      for (int i = 0; i < 3; i++) {
        await enviarDatos('inactivo');
        // Esperamos medio segundo entre intentos para no saturar el socket
        await Future.delayed(const Duration(milliseconds: 500));
      }
      print("Proceso de guardado finalizado.");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rastreador GPS Profesional"),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: "ID de Usuario / Vehículo",
                hintText: "Ej: Chofer_01",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_shipping),
              ),
              enabled: !estaActivo, // Bloqueado mientras envía
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () {
                if (_idController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("¡Error! El ID no puede estar vacío")),
                  );
                  return;
                }
                setState(() {
                  estaActivo = !estaActivo;
                });
                controlarCiclo(estaActivo);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: estaActivo ? Colors.green[600] : Colors.red[600],
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        estaActivo ? Icons.stop_circle : Icons.play_arrow,
                        color: Colors.white,
                        size: 30,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        estaActivo ? 'DETENER RASTREO' : 'INICIAR RASTREO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (estaActivo)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text("Transmitiendo coordenadas en tiempo real...",
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}