#pragma once

namespace fmce
{
namespace discord
{

	bool init(const char* applicationId, const char* name);

	void update(const char* details, const char* state, const char* largeImage, const char* largeText, const char* smallImage,
				const char* smallText, int startSeconds, int endSeconds);

	void clear();

	void tick();

	void shutdown();

	const char* lastError();
}
}
