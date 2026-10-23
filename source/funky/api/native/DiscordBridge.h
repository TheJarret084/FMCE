#pragma once

// Puente C++ minimo entre Haxe (hxcpp) y el Discord Social SDK (discordpp.h).
// Este header NO incluye el SDK (asi el codigo que genera Haxe sigue compilando con el estandar de siempre):
// el SDK solo se ve en DiscordBridge.cpp, que se compila aparte con C++17.

namespace fmce
{
namespace discord
{
	/** Crea el cliente del SDK con el ID de aplicacion (texto: no cabe en un Float) y el nombre fijo de la actividad. */
	bool init(const char* applicationId, const char* name);

	/** Rich presence. Un texto vacio = ese campo no se manda. Tiempos en segundos Unix; 0 = sin tiempo. */
	void update(const char* details, const char* state, const char* largeImage, const char* largeText, const char* smallImage,
				const char* smallText, int startSeconds, int endSeconds);

	/** Quita la presencia. */
	void clear();

	/** Procesa los callbacks del SDK. Llamar seguido (cada frame) desde el hilo principal. */
	void tick();

	/** Suelta el cliente. */
	void shutdown();

	/** Ultimo mensaje de error del SDK ("" si no hubo). */
	const char* lastError();
}
}
