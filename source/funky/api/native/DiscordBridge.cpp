

#define DISCORDPP_IMPLEMENTATION
#include "discordpp.h"

#include "DiscordBridge.h"

#include <cstdio>
#include <cstdlib>
#include <memory>
#include <optional>
#include <string>
#include <chrono>
#include <thread>

namespace
{
	std::unique_ptr<discordpp::Client> g_client;
	uint64_t g_applicationId = 0;
	std::string g_name;
	std::string g_lastError;

	std::optional<std::string> opt(const char* text)
	{
		if (text == nullptr || text[0] == '\0') return std::nullopt;
		return std::string(text);
	}
}

namespace fmce
{
namespace discord
{
	bool init(const char* applicationId, const char* name)
	{
		if (g_client) return true;

		g_applicationId = applicationId != nullptr ? std::strtoull(applicationId, nullptr, 10) : 0;
		if (g_applicationId == 0)
		{
			g_lastError = "ID de aplicacion invalido";
			return false;
		}

		g_name = name != nullptr ? name : "";
		g_client = std::make_unique<discordpp::Client>();

		g_client->AddLogCallback(
			[](std::string message, discordpp::LoggingSeverity severity)
			{
				if (severity >= discordpp::LoggingSeverity::Warning)
				{
					g_lastError = message;
					std::fprintf(stderr, "[Discord SDK] %s\n", message.c_str());
				}
			},
			discordpp::LoggingSeverity::Warning);

		g_client->SetApplicationId(g_applicationId);
		return true;
	}

	void update(const char* details, const char* state, const char* largeImage, const char* largeText, const char* smallImage,
				const char* smallText, int startSeconds, int endSeconds)
	{
		if (!g_client) return;

		discordpp::Activity activity;
		activity.SetType(discordpp::ActivityTypes::Playing);

		if (!g_name.empty()) activity.SetName(g_name);
		activity.SetDetails(opt(details));
		activity.SetState(opt(state));

		if (opt(largeImage) || opt(smallImage))
		{
			discordpp::ActivityAssets assets;
			assets.SetLargeImage(opt(largeImage));
			assets.SetLargeText(opt(largeText));
			assets.SetSmallImage(opt(smallImage));
			assets.SetSmallText(opt(smallText));
			activity.SetAssets(assets);
		}

		if (startSeconds > 0 || endSeconds > 0)
		{
			discordpp::ActivityTimestamps timestamps;
			if (startSeconds > 0) timestamps.SetStart(static_cast<uint64_t>(startSeconds) * 1000ULL);
			if (endSeconds > 0) timestamps.SetEnd(static_cast<uint64_t>(endSeconds) * 1000ULL);
			activity.SetTimestamps(timestamps);
		}

		g_client->UpdateRichPresence(activity,
									 [](discordpp::ClientResult result)
									 {
										 if (!result.Successful()) g_lastError = result.Error();
									 });
	}

	void clear()
	{
		if (g_client) g_client->ClearRichPresence();
	}

	void tick()
	{
		if (g_client) discordpp::RunCallbacks();
	}

	void shutdown()
	{
		if (!g_client) return;
		g_client->ClearRichPresence();

		for (int i = 0; i < 30; ++i)
		{
			discordpp::RunCallbacks();
			std::this_thread::sleep_for(std::chrono::milliseconds(10));
		}

		g_client.reset();
	}

	const char* lastError()
	{
		return g_lastError.c_str();
	}
}
}
