
#ifndef DISCORD_HEADER_DISCORDPP_H_
#define DISCORD_HEADER_DISCORDPP_H_
#include "cdiscord.h"
#include <atomic>
#include <cassert>
#include <cstring>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

namespace discordpp {

enum class DiscordObjectState {

    Invalid,

    Owned,
};

inline void RunCallbacks()
{
    Discord_RunCallbacks();
}

enum class ActivityActionTypes {

    Invalid = 0,

    Join = 1,

    JoinRequest = 5,
};

enum class ActivityPartyPrivacy {

    Private = 0,

    Public = 1,
};

enum class ActivityTypes {

    Playing = 0,

    Streaming = 1,

    Listening = 2,

    Watching = 3,

    CustomStatus = 4,

    Competing = 5,

    HangStatus = 6,
};

enum class StatusDisplayTypes {

    Name = 0,

    State = 1,

    Details = 2,
};

enum class ActivityGamePlatforms {

    Desktop = 1,

    Xbox = 2,

    Samsung = 4,

    IOS = 8,

    Android = 16,

    Embedded = 32,

    PS4 = 64,

    PS5 = 128,
};

enum class ErrorType {

    None = 0,

    NetworkError = 1,

    HTTPError = 2,

    ClientNotReady = 3,

    Disabled = 4,

    ClientDestroyed = 5,

    ValidationError = 6,

    Aborted = 7,

    AuthorizationFailed = 8,

    RPCError = 9,
};

enum class HttpStatusCode {

    None = 0,

    Continue = 100,

    SwitchingProtocols = 101,

    Processing = 102,

    EarlyHints = 103,

    Ok = 200,

    Created = 201,

    Accepted = 202,

    NonAuthoritativeInfo = 203,

    NoContent = 204,

    ResetContent = 205,

    PartialContent = 206,

    MultiStatus = 207,

    AlreadyReported = 208,

    ImUsed = 209,

    MultipleChoices = 300,

    MovedPermanently = 301,

    Found = 302,

    SeeOther = 303,

    NotModified = 304,

    TemporaryRedirect = 307,

    PermanentRedirect = 308,

    BadRequest = 400,

    Unauthorized = 401,

    PaymentRequired = 402,

    Forbidden = 403,

    NotFound = 404,

    MethodNotAllowed = 405,

    NotAcceptable = 406,

    ProxyAuthRequired = 407,

    RequestTimeout = 408,

    Conflict = 409,

    Gone = 410,

    LengthRequired = 411,

    PreconditionFailed = 412,

    PayloadTooLarge = 413,

    UriTooLong = 414,

    UnsupportedMediaType = 415,

    RangeNotSatisfiable = 416,

    ExpectationFailed = 417,

    MisdirectedRequest = 421,

    UnprocessableEntity = 422,

    Locked = 423,

    FailedDependency = 424,

    TooEarly = 425,

    UpgradeRequired = 426,

    PreconditionRequired = 428,

    TooManyRequests = 429,

    RequestHeaderFieldsTooLarge = 431,

    InternalServerError = 500,

    NotImplemented = 501,

    BadGateway = 502,

    ServiceUnavailable = 503,

    GatewayTimeout = 504,

    HttpVersionNotSupported = 505,

    VariantAlsoNegotiates = 506,

    InsufficientStorage = 507,

    LoopDetected = 508,

    NotExtended = 510,

    NetworkAuthorizationRequired = 511,
};

enum class AuthenticationCodeChallengeMethod {

    S256 = 0,
};

enum class IntegrationType {

    GuildInstall = 0,

    UserInstall = 1,
};

enum class ChannelType {

    GuildText = 0,

    Dm = 1,

    GuildVoice = 2,

    GroupDm = 3,

    GuildCategory = 4,

    GuildNews = 5,

    GuildStore = 6,

    GuildNewsThread = 10,

    GuildPublicThread = 11,

    GuildPrivateThread = 12,

    GuildStageVoice = 13,

    GuildDirectory = 14,

    GuildForum = 15,

    GuildMedia = 16,

    Lobby = 17,

    EphemeralDm = 18,
};

enum class AdditionalContentType {

    Other = 0,

    Attachment = 1,

    Poll = 2,

    VoiceMessage = 3,

    Thread = 4,

    Embed = 5,

    Sticker = 6,
};

enum class VoiceInputModeType {

    VoiceActivity = 0,

    PushToTalk = 1,
};

enum class AudioSystem {

    Standard = 0,

    Game = 1,
};

enum class AudioModeType {

    MODE_UNINIT = 0,

    MODE_VAD = 1,

    MODE_PTT = 2,
};

enum class RelationshipType {

    None = 0,

    Friend = 1,

    Blocked = 2,

    PendingIncoming = 3,

    PendingOutgoing = 4,

    Implicit = 5,

    Suggestion = 6,
};

enum class ExternalIdentityProviderType {

    OIDC = 0,

    EpicOnlineServices = 1,

    Steam = 2,

    Unity = 3,

    DiscordBot = 4,

    None = 5,

    Unknown = 6,
};

enum class StatusType {

    Online = 0,

    Offline = 1,

    Blocked = 2,

    Idle = 3,

    Dnd = 4,

    Invisible = 5,

    Streaming = 6,

    Unknown = 7,
};

enum class DisclosureTypes {

    MessageDataVisibleOnDiscord = 3,
};

enum class AuthorizationTokenType {

    User = 0,

    Bearer = 1,
};

enum class AuthenticationExternalAuthType {

    OIDC = 0,

    EpicOnlineServicesAccessToken = 1,

    EpicOnlineServicesIdToken = 2,

    SteamSessionTicket = 3,

    UnityServicesIdToken = 4,

    DiscordBotIssuedAccessToken = 5,

    AppleIdToken = 6,

    PlayStationNetworkIdToken = 7,
};

enum class LoggingSeverity {

    Verbose = 1,

    Info = 2,

    Warning = 3,

    Error = 4,

    None = 5,
};

enum class RelationshipGroupType {

    OnlinePlayingGame = 0,

    OnlineElsewhere = 1,

    Offline = 2,
};
class ActivityInvite;
class ActivityAssets;
class ActivityTimestamps;
class ActivityParty;
class ActivitySecrets;
class ActivityButton;
class Activity;
class ClientResult;
class AuthorizationCodeChallenge;
class AuthorizationCodeVerifier;
class AuthorizationArgs;
class DeviceAuthorizationArgs;
class VoiceStateHandle;
class VADThresholdSettings;
class Call;
class ChannelHandle;
class GuildMinimal;
class GuildChannel;
class LinkedLobby;
class LinkedChannel;
class RelationshipHandle;
class UserApplicationProfileHandle;
class UserHandle;
class LobbyMemberHandle;
class LobbyHandle;
class AdditionalContent;
class MessageHandle;
class AudioDevice;
class VoiceSettings;
class UserMessageSummary;
class ClientCreateOptions;
class Client;
class CallInfoHandle;

class ActivityInvite {

    mutable Discord_ActivityInvite instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_ActivityInvite* instance() const { return &instance_; }

    explicit ActivityInvite(Discord_ActivityInvite instance, DiscordObjectState state);
    ~ActivityInvite();

    ActivityInvite(ActivityInvite&& other) noexcept;

    ActivityInvite& operator=(ActivityInvite&& other) noexcept;

    static const ActivityInvite nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    ActivityInvite(const ActivityInvite& rhs);

    ActivityInvite& operator=(const ActivityInvite& rhs);

    explicit ActivityInvite();

    void Drop();

    uint64_t SenderId() const;

    void SetSenderId(uint64_t SenderId);

    uint64_t ChannelId() const;

    void SetChannelId(uint64_t ChannelId);

    uint64_t MessageId() const;

    void SetMessageId(uint64_t MessageId);

    discordpp::ActivityActionTypes Type() const;

    void SetType(discordpp::ActivityActionTypes Type);

    uint64_t ApplicationId() const;

    void SetApplicationId(uint64_t ApplicationId);

    uint64_t ParentApplicationId() const;

    void SetParentApplicationId(uint64_t ParentApplicationId);

    std::string PartyId() const;

    void SetPartyId(std::string PartyId);

    std::string SessionId() const;

    void SetSessionId(std::string SessionId);

    bool IsValid() const;

    void SetIsValid(bool IsValid);
};

class ActivityAssets {

    mutable Discord_ActivityAssets instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_ActivityAssets* instance() const { return &instance_; }

    explicit ActivityAssets(Discord_ActivityAssets instance, DiscordObjectState state);
    ~ActivityAssets();

    ActivityAssets(ActivityAssets&& other) noexcept;

    ActivityAssets& operator=(ActivityAssets&& other) noexcept;

    static const ActivityAssets nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    ActivityAssets(const ActivityAssets& arg0);

    ActivityAssets& operator=(const ActivityAssets& arg0);

    explicit ActivityAssets();

    void Drop();

    std::optional<std::string> LargeImage() const;

    void SetLargeImage(std::optional<std::string> LargeImage);

    std::optional<std::string> LargeText() const;

    void SetLargeText(std::optional<std::string> LargeText);

    std::optional<std::string> LargeUrl() const;

    void SetLargeUrl(std::optional<std::string> LargeUrl);

    std::optional<std::string> SmallImage() const;

    void SetSmallImage(std::optional<std::string> SmallImage);

    std::optional<std::string> SmallText() const;

    void SetSmallText(std::optional<std::string> SmallText);

    std::optional<std::string> SmallUrl() const;

    void SetSmallUrl(std::optional<std::string> SmallUrl);

    std::optional<std::string> InviteCoverImage() const;

    void SetInviteCoverImage(std::optional<std::string> InviteCoverImage);
};

class ActivityTimestamps {

    mutable Discord_ActivityTimestamps instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_ActivityTimestamps* instance() const { return &instance_; }

    explicit ActivityTimestamps(Discord_ActivityTimestamps instance, DiscordObjectState state);
    ~ActivityTimestamps();

    ActivityTimestamps(ActivityTimestamps&& other) noexcept;

    ActivityTimestamps& operator=(ActivityTimestamps&& other) noexcept;

    static const ActivityTimestamps nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    ActivityTimestamps(const ActivityTimestamps& arg0);

    ActivityTimestamps& operator=(const ActivityTimestamps& arg0);

    explicit ActivityTimestamps();

    void Drop();

    uint64_t Start() const;

    void SetStart(uint64_t Start);

    uint64_t End() const;

    void SetEnd(uint64_t End);
};

class ActivityParty {

    mutable Discord_ActivityParty instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_ActivityParty* instance() const { return &instance_; }

    explicit ActivityParty(Discord_ActivityParty instance, DiscordObjectState state);
    ~ActivityParty();

    ActivityParty(ActivityParty&& other) noexcept;

    ActivityParty& operator=(ActivityParty&& other) noexcept;

    static const ActivityParty nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    ActivityParty(const ActivityParty& arg0);

    ActivityParty& operator=(const ActivityParty& arg0);

    explicit ActivityParty();

    void Drop();

    std::string Id() const;

    void SetId(std::string Id);

    int32_t CurrentSize() const;

    void SetCurrentSize(int32_t CurrentSize);

    int32_t MaxSize() const;

    void SetMaxSize(int32_t MaxSize);

    discordpp::ActivityPartyPrivacy Privacy() const;

    void SetPrivacy(discordpp::ActivityPartyPrivacy Privacy);
};

class ActivitySecrets {

    mutable Discord_ActivitySecrets instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_ActivitySecrets* instance() const { return &instance_; }

    explicit ActivitySecrets(Discord_ActivitySecrets instance, DiscordObjectState state);
    ~ActivitySecrets();

    ActivitySecrets(ActivitySecrets&& other) noexcept;

    ActivitySecrets& operator=(ActivitySecrets&& other) noexcept;

    static const ActivitySecrets nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    ActivitySecrets(const ActivitySecrets& arg0);

    ActivitySecrets& operator=(const ActivitySecrets& arg0);

    explicit ActivitySecrets();

    void Drop();

    std::string Join() const;

    void SetJoin(std::string Join);
};

class ActivityButton {

    mutable Discord_ActivityButton instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_ActivityButton* instance() const { return &instance_; }

    explicit ActivityButton(Discord_ActivityButton instance, DiscordObjectState state);
    ~ActivityButton();

    ActivityButton(ActivityButton&& other) noexcept;

    ActivityButton& operator=(ActivityButton&& other) noexcept;

    static const ActivityButton nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    ActivityButton(const ActivityButton& arg0);

    ActivityButton& operator=(const ActivityButton& arg0);

    explicit ActivityButton();

    void Drop();

    std::string Label() const;

    void SetLabel(std::string Label);

    std::string Url() const;

    void SetUrl(std::string Url);
};

class Activity {

    mutable Discord_Activity instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_Activity* instance() const { return &instance_; }

    explicit Activity(Discord_Activity instance, DiscordObjectState state);
    ~Activity();

    Activity(Activity&& other) noexcept;

    Activity& operator=(Activity&& other) noexcept;

    static const Activity nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    Activity(const Activity& arg0);

    Activity& operator=(const Activity& arg0);

    explicit Activity();

    void Drop();

    void AddButton(discordpp::ActivityButton button);

    bool Equals(discordpp::Activity other) const;

    std::vector<discordpp::ActivityButton> GetButtons() const;

    std::string Name() const;

    void SetName(std::string Name);

    discordpp::ActivityTypes Type() const;

    void SetType(discordpp::ActivityTypes Type);

    std::optional<discordpp::StatusDisplayTypes> StatusDisplayType() const;

    void SetStatusDisplayType(std::optional<discordpp::StatusDisplayTypes> StatusDisplayType);

    std::optional<std::string> State() const;

    void SetState(std::optional<std::string> State);

    std::optional<std::string> StateUrl() const;

    void SetStateUrl(std::optional<std::string> StateUrl);

    std::optional<std::string> Details() const;

    void SetDetails(std::optional<std::string> Details);

    std::optional<std::string> DetailsUrl() const;

    void SetDetailsUrl(std::optional<std::string> DetailsUrl);

    std::optional<uint64_t> ApplicationId() const;

    void SetApplicationId(std::optional<uint64_t> ApplicationId);

    std::optional<uint64_t> ParentApplicationId() const;

    void SetParentApplicationId(std::optional<uint64_t> ParentApplicationId);

    std::optional<discordpp::ActivityAssets> Assets() const;

    void SetAssets(std::optional<discordpp::ActivityAssets> Assets);

    std::optional<discordpp::ActivityTimestamps> Timestamps() const;

    void SetTimestamps(std::optional<discordpp::ActivityTimestamps> Timestamps);

    std::optional<discordpp::ActivityParty> Party() const;

    void SetParty(std::optional<discordpp::ActivityParty> Party);

    std::optional<discordpp::ActivitySecrets> Secrets() const;

    void SetSecrets(std::optional<discordpp::ActivitySecrets> Secrets);

    discordpp::ActivityGamePlatforms SupportedPlatforms() const;

    void SetSupportedPlatforms(discordpp::ActivityGamePlatforms SupportedPlatforms);
};

class ClientResult {

    mutable Discord_ClientResult instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_ClientResult* instance() const { return &instance_; }

    explicit ClientResult(Discord_ClientResult instance, DiscordObjectState state);
    ~ClientResult();

    ClientResult(ClientResult&& other) noexcept;

    ClientResult& operator=(ClientResult&& other) noexcept;

    static const ClientResult nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    ClientResult(const ClientResult& arg0);

    ClientResult& operator=(const ClientResult& arg0);

    void Drop();

    std::string ToString() const;

    discordpp::ErrorType Type() const;

    void SetType(discordpp::ErrorType Type);

    std::string Error() const;

    void SetError(std::string Error);

    int32_t ErrorCode() const;

    void SetErrorCode(int32_t ErrorCode);

    discordpp::HttpStatusCode Status() const;

    void SetStatus(discordpp::HttpStatusCode Status);

    std::string ResponseBody() const;

    void SetResponseBody(std::string ResponseBody);

    bool Successful() const;

    void SetSuccessful(bool Successful);

    bool Retryable() const;

    void SetRetryable(bool Retryable);

    float RetryAfter() const;

    void SetRetryAfter(float RetryAfter);
};

class AuthorizationCodeChallenge {

    mutable Discord_AuthorizationCodeChallenge instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_AuthorizationCodeChallenge* instance() const { return &instance_; }

    explicit AuthorizationCodeChallenge(Discord_AuthorizationCodeChallenge instance,
                                        DiscordObjectState state);
    ~AuthorizationCodeChallenge();

    AuthorizationCodeChallenge(AuthorizationCodeChallenge&& other) noexcept;

    AuthorizationCodeChallenge& operator=(AuthorizationCodeChallenge&& other) noexcept;

    static const AuthorizationCodeChallenge nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    AuthorizationCodeChallenge(const AuthorizationCodeChallenge& arg0);

    AuthorizationCodeChallenge& operator=(const AuthorizationCodeChallenge& arg0);

    explicit AuthorizationCodeChallenge();

    void Drop();

    discordpp::AuthenticationCodeChallengeMethod Method() const;

    void SetMethod(discordpp::AuthenticationCodeChallengeMethod Method);

    std::string Challenge() const;

    void SetChallenge(std::string Challenge);
};

class AuthorizationCodeVerifier {

    mutable Discord_AuthorizationCodeVerifier instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_AuthorizationCodeVerifier* instance() const { return &instance_; }

    explicit AuthorizationCodeVerifier(Discord_AuthorizationCodeVerifier instance,
                                       DiscordObjectState state);
    ~AuthorizationCodeVerifier();

    AuthorizationCodeVerifier(AuthorizationCodeVerifier&& other) noexcept;

    AuthorizationCodeVerifier& operator=(AuthorizationCodeVerifier&& other) noexcept;

    static const AuthorizationCodeVerifier nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    AuthorizationCodeVerifier(const AuthorizationCodeVerifier& arg0);

    AuthorizationCodeVerifier& operator=(const AuthorizationCodeVerifier& arg0);

    void Drop();

    discordpp::AuthorizationCodeChallenge Challenge() const;

    void SetChallenge(discordpp::AuthorizationCodeChallenge Challenge);

    std::string Verifier() const;

    void SetVerifier(std::string Verifier);
};

class AuthorizationArgs {

    mutable Discord_AuthorizationArgs instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_AuthorizationArgs* instance() const { return &instance_; }

    explicit AuthorizationArgs(Discord_AuthorizationArgs instance, DiscordObjectState state);
    ~AuthorizationArgs();

    AuthorizationArgs(AuthorizationArgs&& other) noexcept;

    AuthorizationArgs& operator=(AuthorizationArgs&& other) noexcept;

    static const AuthorizationArgs nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    AuthorizationArgs(const AuthorizationArgs& arg0);

    AuthorizationArgs& operator=(const AuthorizationArgs& arg0);

    explicit AuthorizationArgs();

    void Drop();

    uint64_t ClientId() const;

    void SetClientId(uint64_t ClientId);

    std::string Scopes() const;

    void SetScopes(std::string Scopes);

    std::optional<std::string> State() const;

    void SetState(std::optional<std::string> State);

    std::optional<std::string> Nonce() const;

    void SetNonce(std::optional<std::string> Nonce);

    std::optional<discordpp::AuthorizationCodeChallenge> CodeChallenge() const;

    void SetCodeChallenge(std::optional<discordpp::AuthorizationCodeChallenge> CodeChallenge);

    std::optional<discordpp::IntegrationType> IntegrationType() const;

    void SetIntegrationType(std::optional<discordpp::IntegrationType> IntegrationType);

    std::optional<std::string> CustomSchemeParam() const;

    void SetCustomSchemeParam(std::optional<std::string> CustomSchemeParam);
};

class DeviceAuthorizationArgs {

    mutable Discord_DeviceAuthorizationArgs instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_DeviceAuthorizationArgs* instance() const { return &instance_; }

    explicit DeviceAuthorizationArgs(Discord_DeviceAuthorizationArgs instance,
                                     DiscordObjectState state);
    ~DeviceAuthorizationArgs();

    DeviceAuthorizationArgs(DeviceAuthorizationArgs&& other) noexcept;

    DeviceAuthorizationArgs& operator=(DeviceAuthorizationArgs&& other) noexcept;

    static const DeviceAuthorizationArgs nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    DeviceAuthorizationArgs(const DeviceAuthorizationArgs& arg0);

    DeviceAuthorizationArgs& operator=(const DeviceAuthorizationArgs& arg0);

    explicit DeviceAuthorizationArgs();

    void Drop();

    uint64_t ClientId() const;

    void SetClientId(uint64_t ClientId);

    std::string Scopes() const;

    void SetScopes(std::string Scopes);
};

class VoiceStateHandle {

    mutable Discord_VoiceStateHandle instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_VoiceStateHandle* instance() const { return &instance_; }

    explicit VoiceStateHandle(Discord_VoiceStateHandle instance, DiscordObjectState state);
    ~VoiceStateHandle();

    VoiceStateHandle(VoiceStateHandle&& other) noexcept;

    VoiceStateHandle& operator=(VoiceStateHandle&& other) noexcept;

    static const VoiceStateHandle nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    VoiceStateHandle(const VoiceStateHandle& other);

    VoiceStateHandle& operator=(const VoiceStateHandle& other);

    void Drop();

    bool SelfDeaf() const;

    bool SelfMute() const;
};

class VADThresholdSettings {

    mutable Discord_VADThresholdSettings instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_VADThresholdSettings* instance() const { return &instance_; }

    explicit VADThresholdSettings(Discord_VADThresholdSettings instance, DiscordObjectState state);
    ~VADThresholdSettings();

    VADThresholdSettings(VADThresholdSettings&& other) noexcept;

    VADThresholdSettings& operator=(VADThresholdSettings&& other) noexcept;

    static const VADThresholdSettings nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    VADThresholdSettings(const VADThresholdSettings&) = delete;
    VADThresholdSettings& operator=(const VADThresholdSettings&) = delete;

    void Drop();

    float VadThreshold() const;

    void SetVadThreshold(float VadThreshold);

    bool Automatic() const;

    void SetAutomatic(bool Automatic);
};

class Call {

    mutable Discord_Call instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    enum class Error {

        None = 0,

        SignalingConnectionFailed = 1,

        SignalingUnexpectedClose = 2,

        VoiceConnectionFailed = 3,

        JoinTimeout = 4,

        Forbidden = 5,
    };

    enum class Status {

        Disconnected = 0,

        Joining = 1,

        Connecting = 2,

        SignalingConnected = 3,

        Connected = 4,

        Reconnecting = 5,

        Disconnecting = 6,
    };

    using OnVoiceStateChanged = std::function<void(uint64_t userId)>;

    using OnParticipantChanged = std::function<void(uint64_t userId, bool added)>;

    using OnSpeakingStatusChanged = std::function<void(uint64_t userId, bool isPlayingSound)>;

    using OnStatusChanged = std::function<
      void(discordpp::Call::Status status, discordpp::Call::Error error, int32_t errorDetail)>;

    Discord_Call* instance() const { return &instance_; }

    explicit Call(Discord_Call instance, DiscordObjectState state);
    ~Call();

    Call(Call&& other) noexcept;

    Call& operator=(Call&& other) noexcept;

    static const Call nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    Call(const Call& other);

    Call& operator=(const Call& other);

    void Drop();

    static std::string ErrorToString(discordpp::Call::Error type);

    discordpp::AudioModeType GetAudioMode();

    uint64_t GetChannelId() const;

    uint64_t GetGuildId() const;

    bool GetLocalMute(uint64_t userId);

    std::vector<uint64_t> GetParticipants() const;

    float GetParticipantVolume(uint64_t userId);

    bool GetPTTActive();

    uint32_t GetPTTReleaseDelay();

    bool GetSelfDeaf();

    bool GetSelfMute();

    discordpp::Call::Status GetStatus() const;

    discordpp::VADThresholdSettings GetVADThreshold() const;

    std::optional<discordpp::VoiceStateHandle> GetVoiceStateHandle(uint64_t userId) const;

    void SetAudioMode(discordpp::AudioModeType audioMode);

    void SetLocalMute(uint64_t userId, bool mute);

    void SetOnVoiceStateChangedCallback(discordpp::Call::OnVoiceStateChanged cb);

    void SetParticipantChangedCallback(discordpp::Call::OnParticipantChanged cb);

    void SetParticipantVolume(uint64_t userId, float volume);

    void SetPTTActive(bool active);

    void SetPTTReleaseDelay(uint32_t releaseDelayMs);

    void SetSelfDeaf(bool deaf);

    void SetSelfMute(bool mute);

    void SetSpeakingStatusChangedCallback(discordpp::Call::OnSpeakingStatusChanged cb);

    void SetStatusChangedCallback(discordpp::Call::OnStatusChanged cb);

    void SetVADThreshold(bool automatic, float threshold);

    static std::string StatusToString(discordpp::Call::Status type);
};

class ChannelHandle {

    mutable Discord_ChannelHandle instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_ChannelHandle* instance() const { return &instance_; }

    explicit ChannelHandle(Discord_ChannelHandle instance, DiscordObjectState state);
    ~ChannelHandle();

    ChannelHandle(ChannelHandle&& other) noexcept;

    ChannelHandle& operator=(ChannelHandle&& other) noexcept;

    static const ChannelHandle nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    ChannelHandle(const ChannelHandle& other);

    ChannelHandle& operator=(const ChannelHandle& other);

    void Drop();

    uint64_t Id() const;

    std::string Name() const;

    std::vector<uint64_t> Recipients() const;

    discordpp::ChannelType Type() const;
};

class GuildMinimal {

    mutable Discord_GuildMinimal instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_GuildMinimal* instance() const { return &instance_; }

    explicit GuildMinimal(Discord_GuildMinimal instance, DiscordObjectState state);
    ~GuildMinimal();

    GuildMinimal(GuildMinimal&& other) noexcept;

    GuildMinimal& operator=(GuildMinimal&& other) noexcept;

    static const GuildMinimal nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    GuildMinimal(const GuildMinimal& arg0);

    GuildMinimal& operator=(const GuildMinimal& arg0);

    void Drop();

    uint64_t Id() const;

    void SetId(uint64_t Id);

    std::string Name() const;

    void SetName(std::string Name);
};

class GuildChannel {

    mutable Discord_GuildChannel instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_GuildChannel* instance() const { return &instance_; }

    explicit GuildChannel(Discord_GuildChannel instance, DiscordObjectState state);
    ~GuildChannel();

    GuildChannel(GuildChannel&& other) noexcept;

    GuildChannel& operator=(GuildChannel&& other) noexcept;

    static const GuildChannel nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    GuildChannel(const GuildChannel& arg0);

    GuildChannel& operator=(const GuildChannel& arg0);

    void Drop();

    uint64_t Id() const;

    void SetId(uint64_t Id);

    std::string Name() const;

    void SetName(std::string Name);

    discordpp::ChannelType Type() const;

    void SetType(discordpp::ChannelType Type);

    int32_t Position() const;

    void SetPosition(int32_t Position);

    std::optional<uint64_t> ParentId() const;

    void SetParentId(std::optional<uint64_t> ParentId);

    bool IsLinkable() const;

    void SetIsLinkable(bool IsLinkable);

    bool IsViewableAndWriteableByAllMembers() const;

    void SetIsViewableAndWriteableByAllMembers(bool IsViewableAndWriteableByAllMembers);

    std::optional<discordpp::LinkedLobby> LinkedLobby() const;

    void SetLinkedLobby(std::optional<discordpp::LinkedLobby> LinkedLobby);
};

class LinkedLobby {

    mutable Discord_LinkedLobby instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_LinkedLobby* instance() const { return &instance_; }

    explicit LinkedLobby(Discord_LinkedLobby instance, DiscordObjectState state);
    ~LinkedLobby();

    LinkedLobby(LinkedLobby&& other) noexcept;

    LinkedLobby& operator=(LinkedLobby&& other) noexcept;

    static const LinkedLobby nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    LinkedLobby(const LinkedLobby& arg0);

    LinkedLobby& operator=(const LinkedLobby& arg0);

    explicit LinkedLobby();

    void Drop();

    uint64_t ApplicationId() const;

    void SetApplicationId(uint64_t ApplicationId);

    uint64_t LobbyId() const;

    void SetLobbyId(uint64_t LobbyId);
};

class LinkedChannel {

    mutable Discord_LinkedChannel instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_LinkedChannel* instance() const { return &instance_; }

    explicit LinkedChannel(Discord_LinkedChannel instance, DiscordObjectState state);
    ~LinkedChannel();

    LinkedChannel(LinkedChannel&& other) noexcept;

    LinkedChannel& operator=(LinkedChannel&& other) noexcept;

    static const LinkedChannel nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    LinkedChannel(const LinkedChannel& arg0);

    LinkedChannel& operator=(const LinkedChannel& arg0);

    void Drop();

    uint64_t Id() const;

    void SetId(uint64_t Id);

    std::string Name() const;

    void SetName(std::string Name);

    uint64_t GuildId() const;

    void SetGuildId(uint64_t GuildId);
};

class RelationshipHandle {

    mutable Discord_RelationshipHandle instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_RelationshipHandle* instance() const { return &instance_; }

    explicit RelationshipHandle(Discord_RelationshipHandle instance, DiscordObjectState state);
    ~RelationshipHandle();

    RelationshipHandle(RelationshipHandle&& other) noexcept;

    RelationshipHandle& operator=(RelationshipHandle&& other) noexcept;

    static const RelationshipHandle nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    RelationshipHandle(const RelationshipHandle& other);

    RelationshipHandle& operator=(const RelationshipHandle& other);

    void Drop();

    discordpp::RelationshipType DiscordRelationshipType() const;

    discordpp::RelationshipType GameRelationshipType() const;

    uint64_t Id() const;

    bool IsSpamRequest() const;

    std::optional<discordpp::UserHandle> User() const;
};

class UserApplicationProfileHandle {

    mutable Discord_UserApplicationProfileHandle instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_UserApplicationProfileHandle* instance() const { return &instance_; }

    explicit UserApplicationProfileHandle(Discord_UserApplicationProfileHandle instance,
                                          DiscordObjectState state);
    ~UserApplicationProfileHandle();

    UserApplicationProfileHandle(UserApplicationProfileHandle&& other) noexcept;

    UserApplicationProfileHandle& operator=(UserApplicationProfileHandle&& other) noexcept;

    static const UserApplicationProfileHandle nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    UserApplicationProfileHandle(const UserApplicationProfileHandle& other);

    UserApplicationProfileHandle& operator=(const UserApplicationProfileHandle& other);

    void Drop();

    std::string AvatarHash() const;

    std::string Metadata() const;

    std::optional<std::string> ProviderId() const;

    std::string ProviderIssuedUserId() const;

    discordpp::ExternalIdentityProviderType ProviderType() const;

    std::string Username() const;
};

class UserHandle {

    mutable Discord_UserHandle instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    enum class AvatarType {

        Gif = 0,

        Webp = 1,

        Png = 2,

        Jpeg = 3,
    };

    Discord_UserHandle* instance() const { return &instance_; }

    explicit UserHandle(Discord_UserHandle instance, DiscordObjectState state);
    ~UserHandle();

    UserHandle(UserHandle&& other) noexcept;

    UserHandle& operator=(UserHandle&& other) noexcept;

    static const UserHandle nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    UserHandle(const UserHandle& arg0);

    UserHandle& operator=(const UserHandle& arg0);

    void Drop();

    std::optional<std::string> Avatar() const;

    static std::string AvatarTypeToString(discordpp::UserHandle::AvatarType type);

    std::string AvatarUrl(discordpp::UserHandle::AvatarType animatedType,
                          discordpp::UserHandle::AvatarType staticType) const;

    std::string DisplayName() const;

    std::optional<discordpp::Activity> GameActivity() const;

    std::optional<std::string> GlobalName() const;

    uint64_t Id() const;

    bool IsProvisional() const;

    discordpp::RelationshipHandle Relationship() const;

    discordpp::StatusType Status() const;

    std::vector<discordpp::UserApplicationProfileHandle> UserApplicationProfiles() const;

    std::string Username() const;
};

class LobbyMemberHandle {

    mutable Discord_LobbyMemberHandle instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_LobbyMemberHandle* instance() const { return &instance_; }

    explicit LobbyMemberHandle(Discord_LobbyMemberHandle instance, DiscordObjectState state);
    ~LobbyMemberHandle();

    LobbyMemberHandle(LobbyMemberHandle&& other) noexcept;

    LobbyMemberHandle& operator=(LobbyMemberHandle&& other) noexcept;

    static const LobbyMemberHandle nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    LobbyMemberHandle(const LobbyMemberHandle& other);

    LobbyMemberHandle& operator=(const LobbyMemberHandle& other);

    void Drop();

    bool CanLinkLobby() const;

    bool Connected() const;

    uint64_t Id() const;

    std::unordered_map<std::string, std::string> Metadata() const;

    std::optional<discordpp::UserHandle> User() const;
};

class LobbyHandle {

    mutable Discord_LobbyHandle instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_LobbyHandle* instance() const { return &instance_; }

    explicit LobbyHandle(Discord_LobbyHandle instance, DiscordObjectState state);
    ~LobbyHandle();

    LobbyHandle(LobbyHandle&& other) noexcept;

    LobbyHandle& operator=(LobbyHandle&& other) noexcept;

    static const LobbyHandle nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    LobbyHandle(const LobbyHandle& other);

    LobbyHandle& operator=(const LobbyHandle& other);

    void Drop();

    std::optional<discordpp::CallInfoHandle> GetCallInfoHandle() const;

    std::optional<discordpp::LobbyMemberHandle> GetLobbyMemberHandle(uint64_t memberId) const;

    uint64_t Id() const;

    std::optional<discordpp::LinkedChannel> LinkedChannel() const;

    std::vector<uint64_t> LobbyMemberIds() const;

    std::vector<discordpp::LobbyMemberHandle> LobbyMembers() const;

    std::unordered_map<std::string, std::string> Metadata() const;
};

class AdditionalContent {

    mutable Discord_AdditionalContent instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_AdditionalContent* instance() const { return &instance_; }

    explicit AdditionalContent(Discord_AdditionalContent instance, DiscordObjectState state);
    ~AdditionalContent();

    AdditionalContent(AdditionalContent&& other) noexcept;

    AdditionalContent& operator=(AdditionalContent&& other) noexcept;

    static const AdditionalContent nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    AdditionalContent(const AdditionalContent& arg0);

    AdditionalContent& operator=(const AdditionalContent& arg0);

    explicit AdditionalContent();

    void Drop();

    bool Equals(discordpp::AdditionalContent rhs) const;

    static std::string TypeToString(discordpp::AdditionalContentType type);

    discordpp::AdditionalContentType Type() const;

    void SetType(discordpp::AdditionalContentType Type);

    std::optional<std::string> Title() const;

    void SetTitle(std::optional<std::string> Title);

    uint8_t Count() const;

    void SetCount(uint8_t Count);
};

class MessageHandle {

    mutable Discord_MessageHandle instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_MessageHandle* instance() const { return &instance_; }

    explicit MessageHandle(Discord_MessageHandle instance, DiscordObjectState state);
    ~MessageHandle();

    MessageHandle(MessageHandle&& other) noexcept;

    MessageHandle& operator=(MessageHandle&& other) noexcept;

    static const MessageHandle nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    MessageHandle(const MessageHandle& other);

    MessageHandle& operator=(const MessageHandle& other);

    void Drop();

    std::optional<discordpp::AdditionalContent> AdditionalContent() const;

    std::optional<std::string> AdditionalName() const;

    std::optional<uint64_t> ApplicationId() const;

    std::optional<discordpp::UserHandle> Author() const;

    uint64_t AuthorId() const;

    std::optional<discordpp::ChannelHandle> Channel() const;

    uint64_t ChannelId() const;

    std::string Content() const;

    std::optional<discordpp::DisclosureTypes> DisclosureType() const;

    uint64_t EditedTimestamp() const;

    uint64_t Id() const;

    std::optional<discordpp::LobbyHandle> Lobby() const;

    std::unordered_map<std::string, std::string> Metadata() const;

    std::unordered_map<std::string, std::string> ModerationMetadata() const;

    std::string RawContent() const;

    std::optional<discordpp::UserHandle> Recipient() const;

    uint64_t RecipientId() const;

    bool SentFromGame() const;

    uint64_t SentTimestamp() const;
};

class AudioDevice {

    mutable Discord_AudioDevice instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_AudioDevice* instance() const { return &instance_; }

    explicit AudioDevice(Discord_AudioDevice instance, DiscordObjectState state);
    ~AudioDevice();

    AudioDevice(AudioDevice&& other) noexcept;

    AudioDevice& operator=(AudioDevice&& other) noexcept;

    static const AudioDevice nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    AudioDevice(const AudioDevice& arg0);

    AudioDevice& operator=(const AudioDevice& arg0);

    void Drop();

    bool Equals(discordpp::AudioDevice rhs);

    std::string Id() const;

    void SetId(std::string Id);

    std::string Name() const;

    void SetName(std::string Name);

    bool IsDefault() const;

    void SetIsDefault(bool IsDefault);
};

class VoiceSettings {

    mutable Discord_VoiceSettings instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_VoiceSettings* instance() const { return &instance_; }

    explicit VoiceSettings(Discord_VoiceSettings instance, DiscordObjectState state);
    ~VoiceSettings();

    VoiceSettings(VoiceSettings&& other) noexcept;

    VoiceSettings& operator=(VoiceSettings&& other) noexcept;

    static const VoiceSettings nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    VoiceSettings(const VoiceSettings& arg0);

    VoiceSettings& operator=(const VoiceSettings& arg0);

    void Drop();

    bool SelfMute() const;

    void SetSelfMute(bool SelfMute);

    bool SelfDeaf() const;

    void SetSelfDeaf(bool SelfDeaf);

    discordpp::VoiceInputModeType InputMode() const;

    void SetInputMode(discordpp::VoiceInputModeType InputMode);

    std::string PttKey() const;

    void SetPttKey(std::string PttKey);

    float InputVolume() const;

    void SetInputVolume(float InputVolume);

    float OutputVolume() const;

    void SetOutputVolume(float OutputVolume);

    bool AutomaticGainControl() const;

    void SetAutomaticGainControl(bool AutomaticGainControl);

    bool EchoCancellation() const;

    void SetEchoCancellation(bool EchoCancellation);

    bool NoiseSuppression() const;

    void SetNoiseSuppression(bool NoiseSuppression);

    bool NoiseCancellation() const;

    void SetNoiseCancellation(bool NoiseCancellation);
};

class UserMessageSummary {

    mutable Discord_UserMessageSummary instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_UserMessageSummary* instance() const { return &instance_; }

    explicit UserMessageSummary(Discord_UserMessageSummary instance, DiscordObjectState state);
    ~UserMessageSummary();

    UserMessageSummary(UserMessageSummary&& other) noexcept;

    UserMessageSummary& operator=(UserMessageSummary&& other) noexcept;

    static const UserMessageSummary nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    UserMessageSummary(const UserMessageSummary& arg0);

    UserMessageSummary& operator=(const UserMessageSummary& arg0);

    void Drop();

    uint64_t LastMessageId() const;

    uint64_t UserId() const;
};

class ClientCreateOptions {

    mutable Discord_ClientCreateOptions instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_ClientCreateOptions* instance() const { return &instance_; }

    explicit ClientCreateOptions(Discord_ClientCreateOptions instance, DiscordObjectState state);
    ~ClientCreateOptions();

    ClientCreateOptions(ClientCreateOptions&& other) noexcept;

    ClientCreateOptions& operator=(ClientCreateOptions&& other) noexcept;

    static const ClientCreateOptions nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    ClientCreateOptions(const ClientCreateOptions& arg0);

    ClientCreateOptions& operator=(const ClientCreateOptions& arg0);

    explicit ClientCreateOptions();

    void Drop();

    std::string WebBase() const;

    void SetWebBase(std::string WebBase);

    std::string ApiBase() const;

    void SetApiBase(std::string ApiBase);

    discordpp::AudioSystem ExperimentalAudioSystem() const;

    void SetExperimentalAudioSystem(discordpp::AudioSystem ExperimentalAudioSystem);

    bool ExperimentalAndroidPreventCommsForBluetooth() const;

    void SetExperimentalAndroidPreventCommsForBluetooth(
      bool ExperimentalAndroidPreventCommsForBluetooth);

    std::optional<uint64_t> CpuAffinityMask() const;

    void SetCpuAffinityMask(std::optional<uint64_t> CpuAffinityMask);
};

class Client {

    mutable Discord_Client instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    enum class Error {

        None = 0,

        ConnectionFailed = 1,

        UnexpectedClose = 2,

        ConnectionCanceled = 3,
    };

    enum class Status {

        Disconnected = 0,

        Connecting = 1,

        Connected = 2,

        Ready = 3,

        Reconnecting = 4,

        Disconnecting = 5,

        HttpWait = 6,
    };

    enum class Thread {

        Client = 0,

        Voice = 1,

        Network = 2,
    };

    using EndCallCallback = std::function<void()>;

    using EndCallsCallback = std::function<void()>;

    using GetCurrentInputDeviceCallback = std::function<void(discordpp::AudioDevice device)>;

    using GetCurrentOutputDeviceCallback = std::function<void(discordpp::AudioDevice device)>;

    using GetInputDevicesCallback =
      std::function<void(std::vector<discordpp::AudioDevice> devices)>;

    using GetOutputDevicesCallback =
      std::function<void(std::vector<discordpp::AudioDevice> devices)>;

    using GetVoiceSettingsCallback =
      std::function<void(discordpp::ClientResult result, discordpp::VoiceSettings settings)>;

    using DeviceChangeCallback =
      std::function<void(std::vector<discordpp::AudioDevice> inputDevices,
                         std::vector<discordpp::AudioDevice> outputDevices)>;

    using SetInputDeviceCallback = std::function<void(discordpp::ClientResult result)>;

    using NoAudioInputCallback = std::function<void(bool inputDetected)>;

    using SetOutputDeviceCallback = std::function<void(discordpp::ClientResult result)>;

    using VoiceParticipantChangedCallback =
      std::function<void(uint64_t lobbyId, uint64_t memberId, bool added)>;

    using VoiceSettingsUpdatedCallback = std::function<void(discordpp::VoiceSettings settings)>;

    using UserAudioReceivedCallback = std::function<void(uint64_t userId,
                                                         int16_t* data,
                                                         uint64_t samplesPerChannel,
                                                         int32_t sampleRate,
                                                         uint64_t channels,
                                                         bool& outShouldMute)>;

    using UserAudioCapturedCallback = std::function<
      void(int16_t* data, uint64_t samplesPerChannel, int32_t sampleRate, uint64_t channels)>;

    using AuthorizationCallback = std::function<
      void(discordpp::ClientResult result, std::string code, std::string redirectUri)>;

    using ExchangeChildTokenCallback =
      std::function<void(discordpp::ClientResult result,
                         std::string accessToken,
                         discordpp::AuthorizationTokenType tokenType,
                         int32_t expiresIn,
                         std::string scopes)>;

    using FetchCurrentUserCallback =
      std::function<void(discordpp::ClientResult result, uint64_t id, std::string name)>;

    using TokenExchangeCallback = std::function<void(discordpp::ClientResult result,
                                                     std::string accessToken,
                                                     std::string refreshToken,
                                                     discordpp::AuthorizationTokenType tokenType,
                                                     int32_t expiresIn,
                                                     std::string scopes)>;

    using AuthorizeRequestCallback = std::function<void()>;

    using RevokeTokenCallback = std::function<void(discordpp::ClientResult result)>;

    using AuthorizeDeviceScreenClosedCallback = std::function<void()>;

    using TokenExpirationCallback = std::function<void()>;

    using UnmergeIntoProvisionalAccountCallback =
      std::function<void(discordpp::ClientResult result)>;

    using UpdateProvisionalAccountDisplayNameCallback =
      std::function<void(discordpp::ClientResult result)>;

    using UpdateTokenCallback = std::function<void(discordpp::ClientResult result)>;

    using DeleteUserMessageCallback = std::function<void(discordpp::ClientResult result)>;

    using EditUserMessageCallback = std::function<void(discordpp::ClientResult result)>;

    using GetLobbyMessagesCallback =
      std::function<void(discordpp::ClientResult result,
                         std::vector<discordpp::MessageHandle> messages)>;

    using UserMessageSummariesCallback =
      std::function<void(discordpp::ClientResult result,
                         std::vector<discordpp::UserMessageSummary> summaries)>;

    using UserMessagesWithLimitCallback =
      std::function<void(discordpp::ClientResult result,
                         std::vector<discordpp::MessageHandle> messages)>;

    using ProvisionalUserMergeRequiredCallback = std::function<void()>;

    using OpenMessageInDiscordCallback = std::function<void(discordpp::ClientResult result)>;

    using SendUserMessageCallback =
      std::function<void(discordpp::ClientResult result, uint64_t messageId)>;

    using MessageCreatedCallback = std::function<void(uint64_t messageId)>;

    using MessageDeletedCallback = std::function<void(uint64_t messageId, uint64_t channelId)>;

    using MessageUpdatedCallback = std::function<void(uint64_t messageId)>;

    using LogCallback =
      std::function<void(std::string message, discordpp::LoggingSeverity severity)>;

    using OpenConnectedGamesSettingsInDiscordCallback =
      std::function<void(discordpp::ClientResult result)>;

    using OnStatusChanged = std::function<
      void(discordpp::Client::Status status, discordpp::Client::Error error, int32_t errorDetail)>;

    using CreateOrJoinLobbyCallback =
      std::function<void(discordpp::ClientResult result, uint64_t lobbyId)>;

    using GetGuildChannelsCallback =
      std::function<void(discordpp::ClientResult result,
                         std::vector<discordpp::GuildChannel> guildChannels)>;

    using GetUserGuildsCallback = std::function<void(discordpp::ClientResult result,
                                                     std::vector<discordpp::GuildMinimal> guilds)>;

    using JoinLinkedLobbyGuildCallback =
      std::function<void(discordpp::ClientResult result, std::string inviteUrl)>;

    using LeaveLobbyCallback = std::function<void(discordpp::ClientResult result)>;

    using LinkOrUnlinkChannelCallback = std::function<void(discordpp::ClientResult result)>;

    using LobbyCreatedCallback = std::function<void(uint64_t lobbyId)>;

    using LobbyDeletedCallback = std::function<void(uint64_t lobbyId)>;

    using LobbyMemberAddedCallback = std::function<void(uint64_t lobbyId, uint64_t memberId)>;

    using LobbyMemberRemovedCallback = std::function<void(uint64_t lobbyId, uint64_t memberId)>;

    using LobbyMemberUpdatedCallback = std::function<void(uint64_t lobbyId, uint64_t memberId)>;

    using LobbyUpdatedCallback = std::function<void(uint64_t lobbyId)>;

    using IsDiscordAppInstalledCallback = std::function<void(bool installed)>;

    using AcceptActivityInviteCallback =
      std::function<void(discordpp::ClientResult result, std::string joinSecret)>;

    using SendActivityInviteCallback = std::function<void(discordpp::ClientResult result)>;

    using ActivityInviteCallback = std::function<void(discordpp::ActivityInvite invite)>;

    using ActivityJoinCallback = std::function<void(std::string joinSecret)>;

    using ActivityJoinWithApplicationCallback =
      std::function<void(uint64_t applicationId, std::string joinSecret)>;

    using UpdateStatusCallback = std::function<void(discordpp::ClientResult result)>;

    using UpdateRichPresenceCallback = std::function<void(discordpp::ClientResult result)>;

    using UpdateRelationshipCallback = std::function<void(discordpp::ClientResult result)>;

    using SendFriendRequestCallback = std::function<void(discordpp::ClientResult result)>;

    using RelationshipCreatedCallback =
      std::function<void(uint64_t userId, bool isDiscordRelationshipUpdate)>;

    using RelationshipDeletedCallback =
      std::function<void(uint64_t userId, bool isDiscordRelationshipUpdate)>;

    using GetDiscordClientConnectedUserCallback =
      std::function<void(discordpp::ClientResult result,
                         std::optional<discordpp::UserHandle> user)>;

    using RelationshipGroupsUpdatedCallback = std::function<void(uint64_t userId)>;

    using UserUpdatedCallback = std::function<void(uint64_t userId)>;

    Discord_Client* instance() const { return &instance_; }

    explicit Client(Discord_Client instance, DiscordObjectState state);
    ~Client();

    Client(Client&& other) noexcept;

    Client& operator=(Client&& other) noexcept;

    static const Client nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    Client(const Client&) = delete;
    Client& operator=(const Client&) = delete;

    explicit Client();

    explicit Client(std::string apiBase, std::string webBase);

    explicit Client(discordpp::ClientCreateOptions options);

    void Drop();

    static std::string ErrorToString(discordpp::Client::Error type);

    uint64_t GetApplicationId();

    [[deprecated("Please use GetCurrentUserV2 instead. This will be removed in a future version.")]]
    discordpp::UserHandle GetCurrentUser() const;

    static std::string GetDefaultAudioDeviceId();

    static std::string GetDefaultCommunicationScopes();

    static std::string GetDefaultPresenceScopes();

    static std::string GetVersionHash();

    static int32_t GetVersionMajor();

    static int32_t GetVersionMinor();

    static int32_t GetVersionPatch();

    void SetHttpRequestTimeout(int32_t httpTimeoutInMilliseconds);

    static std::string StatusToString(discordpp::Client::Status type);

    static std::string ThreadToString(discordpp::Client::Thread type);

    void EndCall(uint64_t channelId, discordpp::Client::EndCallCallback callback);

    void EndCalls(discordpp::Client::EndCallsCallback callback);

    discordpp::Call GetCall(uint64_t channelId);

    std::vector<discordpp::Call> GetCalls();

    void GetCurrentInputDevice(discordpp::Client::GetCurrentInputDeviceCallback cb);

    void GetCurrentOutputDevice(discordpp::Client::GetCurrentOutputDeviceCallback cb);

    void GetInputDevices(discordpp::Client::GetInputDevicesCallback cb);

    float GetInputVolume();

    void GetOutputDevices(discordpp::Client::GetOutputDevicesCallback cb);

    float GetOutputVolume();

    bool GetSelfDeafAll() const;

    bool GetSelfMuteAll() const;

    void GetVoiceSettings(discordpp::Client::GetVoiceSettingsCallback cb);

    void SetAecDump(bool on);

    void SetAutomaticGainControl(bool on);

    void SetDeviceChangeCallback(discordpp::Client::DeviceChangeCallback callback);

    void SetEchoCancellation(bool on);

    void SetEngineManagedAudioSession(bool isEngineManaged);

    void SetInputDevice(std::string deviceId, discordpp::Client::SetInputDeviceCallback cb);

    void SetInputVolume(float inputVolume);

    void SetNoAudioInputCallback(discordpp::Client::NoAudioInputCallback callback);

    void SetNoAudioInputThreshold(float dBFSThreshold);

    void SetNoiseCancellation(bool on);

    void SetNoiseSuppression(bool on);

    void SetOpusHardwareCoding(bool encode, bool decode);

    void SetOutputDevice(std::string deviceId, discordpp::Client::SetOutputDeviceCallback cb);

    void SetOutputVolume(float outputVolume);

    void SetSelfDeafAll(bool deaf);

    void SetSelfMuteAll(bool mute);

    [[deprecated("Calling Client::SetSpeakerMode is DEPRECATED.")]]
    bool SetSpeakerMode(bool speakerMode);

    void SetThreadPriority(discordpp::Client::Thread thread, int32_t priority);

    void SetVoiceParticipantChangedCallback(discordpp::Client::VoiceParticipantChangedCallback cb);

    void SetVoiceSettingsUpdatedCallback(discordpp::Client::VoiceSettingsUpdatedCallback callback);

    bool ShowAudioRoutePicker();

    discordpp::Call StartCall(uint64_t channelId);

    discordpp::Call StartCallWithAudioCallbacks(
      uint64_t lobbyId,
      discordpp::Client::UserAudioReceivedCallback receivedCb,
      discordpp::Client::UserAudioCapturedCallback capturedCb);

    void AbortAuthorize();

    void AbortGetTokenFromDevice();

    void Authorize(discordpp::AuthorizationArgs args,
                   discordpp::Client::AuthorizationCallback callback);

    void CloseAuthorizeDeviceScreen();

    discordpp::AuthorizationCodeVerifier CreateAuthorizationCodeVerifier();

    void ExchangeChildToken(std::string const& parentApplicationToken,
                            uint64_t childApplicationId,
                            discordpp::Client::ExchangeChildTokenCallback callback);

    void FetchCurrentUser(discordpp::AuthorizationTokenType tokenType,
                          std::string const& token,
                          discordpp::Client::FetchCurrentUserCallback callback);

    void GetProvisionalToken(uint64_t applicationId,
                             discordpp::AuthenticationExternalAuthType externalAuthType,
                             std::string const& externalAuthToken,
                             discordpp::Client::TokenExchangeCallback callback);

    void GetToken(uint64_t applicationId,
                  std::string const& code,
                  std::string const& codeVerifier,
                  std::string const& redirectUri,
                  discordpp::Client::TokenExchangeCallback callback);

    void GetTokenFromDevice(discordpp::DeviceAuthorizationArgs args,
                            discordpp::Client::TokenExchangeCallback callback);

    void GetTokenFromDeviceProvisionalMerge(
      discordpp::DeviceAuthorizationArgs args,
      discordpp::AuthenticationExternalAuthType externalAuthType,
      std::string const& externalAuthToken,
      discordpp::Client::TokenExchangeCallback callback);

    void GetTokenFromProvisionalMerge(uint64_t applicationId,
                                      std::string const& code,
                                      std::string const& codeVerifier,
                                      std::string const& redirectUri,
                                      discordpp::AuthenticationExternalAuthType externalAuthType,
                                      std::string const& externalAuthToken,
                                      discordpp::Client::TokenExchangeCallback callback);

    bool IsAuthenticated();

    void OpenAuthorizeDeviceScreen(uint64_t clientId, std::string const& userCode);

    void ProvisionalUserMergeCompleted(bool success);

    void RefreshToken(uint64_t applicationId,
                      std::string const& refreshToken,
                      discordpp::Client::TokenExchangeCallback callback);

    void RegisterAuthorizeRequestCallback(discordpp::Client::AuthorizeRequestCallback callback);

    void RemoveAuthorizeRequestCallback();

    void RevokeToken(uint64_t applicationId,
                     std::string const& token,
                     discordpp::Client::RevokeTokenCallback callback);

    void SetAuthorizeDeviceScreenClosedCallback(
      discordpp::Client::AuthorizeDeviceScreenClosedCallback cb);

    void SetGameWindowPid(int32_t pid);

    void SetTokenExpirationCallback(discordpp::Client::TokenExpirationCallback callback);

    void UnmergeIntoProvisionalAccount(
      uint64_t applicationId,
      discordpp::AuthenticationExternalAuthType externalAuthType,
      std::string const& externalAuthToken,
      discordpp::Client::UnmergeIntoProvisionalAccountCallback callback);

    void UpdateProvisionalAccountDisplayName(
      std::string const& name,
      discordpp::Client::UpdateProvisionalAccountDisplayNameCallback callback);

    void UpdateToken(discordpp::AuthorizationTokenType tokenType,
                     std::string token,
                     discordpp::Client::UpdateTokenCallback callback);

    bool CanOpenMessageInDiscord(uint64_t messageId);

    void DeleteUserMessage(uint64_t recipientId,
                           uint64_t messageId,
                           discordpp::Client::DeleteUserMessageCallback cb);

    void EditUserMessage(uint64_t recipientId,
                         uint64_t messageId,
                         std::string const& content,
                         discordpp::Client::EditUserMessageCallback cb);

    std::optional<discordpp::ChannelHandle> GetChannelHandle(uint64_t channelId) const;

    void GetLobbyMessagesWithLimit(uint64_t lobbyId,
                                   int32_t limit,
                                   discordpp::Client::GetLobbyMessagesCallback cb);

    std::optional<discordpp::MessageHandle> GetMessageHandle(uint64_t messageId) const;

    void GetUserMessageSummaries(discordpp::Client::UserMessageSummariesCallback cb);

    void GetUserMessagesWithLimit(uint64_t recipientId,
                                  int32_t limit,
                                  discordpp::Client::UserMessagesWithLimitCallback cb);

    void OpenMessageInDiscord(
      uint64_t messageId,
      discordpp::Client::ProvisionalUserMergeRequiredCallback provisionalUserMergeRequiredCallback,
      discordpp::Client::OpenMessageInDiscordCallback callback);

    void SendLobbyMessage(uint64_t lobbyId,
                          std::string const& content,
                          discordpp::Client::SendUserMessageCallback cb);

    void SendLobbyMessageWithMetadata(uint64_t lobbyId,
                                      std::string const& content,
                                      std::unordered_map<std::string, std::string> const& metadata,
                                      discordpp::Client::SendUserMessageCallback cb);

    void SendUserMessage(uint64_t recipientId,
                         std::string const& content,
                         discordpp::Client::SendUserMessageCallback cb);

    void SendUserMessageWithMetadata(uint64_t recipientId,
                                     std::string const& content,
                                     std::unordered_map<std::string, std::string> const& metadata,
                                     discordpp::Client::SendUserMessageCallback cb);

    void SetMessageCreatedCallback(discordpp::Client::MessageCreatedCallback cb);

    void SetMessageDeletedCallback(discordpp::Client::MessageDeletedCallback cb);

    void SetMessageUpdatedCallback(discordpp::Client::MessageUpdatedCallback cb);

    void SetShowingChat(bool showingChat);

    void AddLogCallback(discordpp::Client::LogCallback callback,
                        discordpp::LoggingSeverity minSeverity);

    void AddVoiceLogCallback(discordpp::Client::LogCallback callback,
                             discordpp::LoggingSeverity minSeverity);

    void Connect();

    void Disconnect();

    discordpp::Client::Status GetStatus() const;

    void OpenConnectedGamesSettingsInDiscord(
      discordpp::Client::OpenConnectedGamesSettingsInDiscordCallback callback);

    void SetApplicationId(uint64_t applicationId);

    bool SetLogDir(std::string const& path, discordpp::LoggingSeverity minSeverity);

    void SetStatusChangedCallback(discordpp::Client::OnStatusChanged cb);

    void SetVoiceLogDir(std::string const& path, discordpp::LoggingSeverity minSeverity);

    void CreateOrJoinLobby(std::string const& secret,
                           discordpp::Client::CreateOrJoinLobbyCallback callback);

    void CreateOrJoinLobbyWithMetadata(
      std::string const& secret,
      std::unordered_map<std::string, std::string> const& lobbyMetadata,
      std::unordered_map<std::string, std::string> const& memberMetadata,
      discordpp::Client::CreateOrJoinLobbyCallback callback);

    void GetGuildChannels(uint64_t guildId, discordpp::Client::GetGuildChannelsCallback cb);

    std::optional<discordpp::LobbyHandle> GetLobbyHandle(uint64_t lobbyId) const;

    std::vector<uint64_t> GetLobbyIds() const;

    void GetUserGuilds(discordpp::Client::GetUserGuildsCallback cb);

    void JoinLinkedLobbyGuild(
      uint64_t lobbyId,
      discordpp::Client::ProvisionalUserMergeRequiredCallback provisionalUserMergeRequiredCallback,
      discordpp::Client::JoinLinkedLobbyGuildCallback callback);

    void LeaveLobby(uint64_t lobbyId, discordpp::Client::LeaveLobbyCallback callback);

    void LinkChannelToLobby(uint64_t lobbyId,
                            uint64_t channelId,
                            discordpp::Client::LinkOrUnlinkChannelCallback callback);

    void SetLobbyCreatedCallback(discordpp::Client::LobbyCreatedCallback cb);

    void SetLobbyDeletedCallback(discordpp::Client::LobbyDeletedCallback cb);

    void SetLobbyMemberAddedCallback(discordpp::Client::LobbyMemberAddedCallback cb);

    void SetLobbyMemberRemovedCallback(discordpp::Client::LobbyMemberRemovedCallback cb);

    void SetLobbyMemberUpdatedCallback(discordpp::Client::LobbyMemberUpdatedCallback cb);

    void SetLobbyUpdatedCallback(discordpp::Client::LobbyUpdatedCallback cb);

    void UnlinkChannelFromLobby(uint64_t lobbyId,
                                discordpp::Client::LinkOrUnlinkChannelCallback callback);

    void IsDiscordAppInstalled(discordpp::Client::IsDiscordAppInstalledCallback callback);

    void AcceptActivityInvite(discordpp::ActivityInvite invite,
                              discordpp::Client::AcceptActivityInviteCallback cb);

    void ClearRichPresence();

    bool RegisterLaunchCommand(uint64_t applicationId, std::string command);

    bool RegisterLaunchSteamApplication(uint64_t applicationId, uint32_t steamAppId);

    void SendActivityInvite(uint64_t userId,
                            std::string const& content,
                            discordpp::Client::SendActivityInviteCallback cb);

    void SendActivityJoinRequest(uint64_t userId, discordpp::Client::SendActivityInviteCallback cb);

    void SendActivityJoinRequestReply(discordpp::ActivityInvite invite,
                                      discordpp::Client::SendActivityInviteCallback cb);

    void SetActivityInviteCreatedCallback(discordpp::Client::ActivityInviteCallback cb);

    void SetActivityInviteUpdatedCallback(discordpp::Client::ActivityInviteCallback cb);

    void SetActivityJoinCallback(discordpp::Client::ActivityJoinCallback cb);

    void SetActivityJoinWithApplicationCallback(
      discordpp::Client::ActivityJoinWithApplicationCallback cb);

    void SetOnlineStatus(discordpp::StatusType status,
                         discordpp::Client::UpdateStatusCallback callback);

    void UpdateRichPresence(discordpp::Activity activity,
                            discordpp::Client::UpdateRichPresenceCallback cb);

    void AcceptDiscordFriendRequest(uint64_t userId,
                                    discordpp::Client::UpdateRelationshipCallback cb);

    void AcceptGameFriendRequest(uint64_t userId, discordpp::Client::UpdateRelationshipCallback cb);

    void BlockUser(uint64_t userId, discordpp::Client::UpdateRelationshipCallback cb);

    void CancelDiscordFriendRequest(uint64_t userId,
                                    discordpp::Client::UpdateRelationshipCallback cb);

    void CancelGameFriendRequest(uint64_t userId, discordpp::Client::UpdateRelationshipCallback cb);

    discordpp::RelationshipHandle GetRelationshipHandle(uint64_t userId) const;

    std::vector<discordpp::RelationshipHandle> GetRelationships() const;

    std::vector<discordpp::RelationshipHandle> GetRelationshipsByGroup(
      discordpp::RelationshipGroupType groupType) const;

    void RejectDiscordFriendRequest(uint64_t userId,
                                    discordpp::Client::UpdateRelationshipCallback cb);

    void RejectGameFriendRequest(uint64_t userId, discordpp::Client::UpdateRelationshipCallback cb);

    void RemoveDiscordAndGameFriend(uint64_t userId,
                                    discordpp::Client::UpdateRelationshipCallback cb);

    void RemoveGameFriend(uint64_t userId, discordpp::Client::UpdateRelationshipCallback cb);

    std::vector<discordpp::UserHandle> SearchFriendsByUsername(std::string searchStr) const;

    void SendDiscordFriendRequest(std::string const& username,
                                  discordpp::Client::SendFriendRequestCallback cb);

    void SendDiscordFriendRequestById(uint64_t userId,
                                      discordpp::Client::UpdateRelationshipCallback cb);

    void SendGameFriendRequest(std::string const& username,
                               discordpp::Client::SendFriendRequestCallback cb);

    void SendGameFriendRequestById(uint64_t userId,
                                   discordpp::Client::UpdateRelationshipCallback cb);

    void SetRelationshipCreatedCallback(discordpp::Client::RelationshipCreatedCallback cb);

    void SetRelationshipDeletedCallback(discordpp::Client::RelationshipDeletedCallback cb);

    void UnblockUser(uint64_t userId, discordpp::Client::UpdateRelationshipCallback cb);

    std::optional<discordpp::UserHandle> GetCurrentUserV2() const;

    void GetDiscordClientConnectedUser(
      uint64_t applicationId,
      discordpp::Client::GetDiscordClientConnectedUserCallback callback) const;

    std::optional<discordpp::UserHandle> GetUser(uint64_t userId) const;

    void SetRelationshipGroupsUpdatedCallback(
      discordpp::Client::RelationshipGroupsUpdatedCallback cb);

    void SetUserUpdatedCallback(discordpp::Client::UserUpdatedCallback cb);

};

class CallInfoHandle {

    mutable Discord_CallInfoHandle instance_{};
    DiscordObjectState state_ = DiscordObjectState::Invalid;

public:

    Discord_CallInfoHandle* instance() const { return &instance_; }

    explicit CallInfoHandle(Discord_CallInfoHandle instance, DiscordObjectState state);
    ~CallInfoHandle();

    CallInfoHandle(CallInfoHandle&& other) noexcept;

    CallInfoHandle& operator=(CallInfoHandle&& other) noexcept;

    static const CallInfoHandle nullobj;

    operator bool() const { return state_ != DiscordObjectState::Invalid; }

    CallInfoHandle(const CallInfoHandle& other);

    CallInfoHandle& operator=(const CallInfoHandle& other);

    void Drop();

    uint64_t ChannelId() const;

    std::vector<uint64_t> GetParticipants() const;

    std::optional<discordpp::VoiceStateHandle> GetVoiceStateHandle(uint64_t userId) const;

    uint64_t GuildId() const;
};

inline const char* EnumToString(discordpp::ActivityActionTypes value)
{
    switch (value) {
    case discordpp::ActivityActionTypes::Invalid:
        return "Invalid";
    case discordpp::ActivityActionTypes::Join:
        return "Join";
    case discordpp::ActivityActionTypes::JoinRequest:
        return "JoinRequest";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::ActivityPartyPrivacy value)
{
    switch (value) {
    case discordpp::ActivityPartyPrivacy::Private:
        return "Private";
    case discordpp::ActivityPartyPrivacy::Public:
        return "Public";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::ActivityTypes value)
{
    switch (value) {
    case discordpp::ActivityTypes::Playing:
        return "Playing";
    case discordpp::ActivityTypes::Streaming:
        return "Streaming";
    case discordpp::ActivityTypes::Listening:
        return "Listening";
    case discordpp::ActivityTypes::Watching:
        return "Watching";
    case discordpp::ActivityTypes::CustomStatus:
        return "CustomStatus";
    case discordpp::ActivityTypes::Competing:
        return "Competing";
    case discordpp::ActivityTypes::HangStatus:
        return "HangStatus";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::StatusDisplayTypes value)
{
    switch (value) {
    case discordpp::StatusDisplayTypes::Name:
        return "Name";
    case discordpp::StatusDisplayTypes::State:
        return "State";
    case discordpp::StatusDisplayTypes::Details:
        return "Details";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::ActivityGamePlatforms value)
{
    switch (value) {
    case discordpp::ActivityGamePlatforms::Desktop:
        return "Desktop";
    case discordpp::ActivityGamePlatforms::Xbox:
        return "Xbox";
    case discordpp::ActivityGamePlatforms::Samsung:
        return "Samsung";
    case discordpp::ActivityGamePlatforms::IOS:
        return "IOS";
    case discordpp::ActivityGamePlatforms::Android:
        return "Android";
    case discordpp::ActivityGamePlatforms::Embedded:
        return "Embedded";
    case discordpp::ActivityGamePlatforms::PS4:
        return "PS4";
    case discordpp::ActivityGamePlatforms::PS5:
        return "PS5";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::ErrorType value)
{
    switch (value) {
    case discordpp::ErrorType::None:
        return "None";
    case discordpp::ErrorType::NetworkError:
        return "NetworkError";
    case discordpp::ErrorType::HTTPError:
        return "HTTPError";
    case discordpp::ErrorType::ClientNotReady:
        return "ClientNotReady";
    case discordpp::ErrorType::Disabled:
        return "Disabled";
    case discordpp::ErrorType::ClientDestroyed:
        return "ClientDestroyed";
    case discordpp::ErrorType::ValidationError:
        return "ValidationError";
    case discordpp::ErrorType::Aborted:
        return "Aborted";
    case discordpp::ErrorType::AuthorizationFailed:
        return "AuthorizationFailed";
    case discordpp::ErrorType::RPCError:
        return "RPCError";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::HttpStatusCode value)
{
    switch (value) {
    case discordpp::HttpStatusCode::None:
        return "None";
    case discordpp::HttpStatusCode::Continue:
        return "Continue";
    case discordpp::HttpStatusCode::SwitchingProtocols:
        return "SwitchingProtocols";
    case discordpp::HttpStatusCode::Processing:
        return "Processing";
    case discordpp::HttpStatusCode::EarlyHints:
        return "EarlyHints";
    case discordpp::HttpStatusCode::Ok:
        return "Ok";
    case discordpp::HttpStatusCode::Created:
        return "Created";
    case discordpp::HttpStatusCode::Accepted:
        return "Accepted";
    case discordpp::HttpStatusCode::NonAuthoritativeInfo:
        return "NonAuthoritativeInfo";
    case discordpp::HttpStatusCode::NoContent:
        return "NoContent";
    case discordpp::HttpStatusCode::ResetContent:
        return "ResetContent";
    case discordpp::HttpStatusCode::PartialContent:
        return "PartialContent";
    case discordpp::HttpStatusCode::MultiStatus:
        return "MultiStatus";
    case discordpp::HttpStatusCode::AlreadyReported:
        return "AlreadyReported";
    case discordpp::HttpStatusCode::ImUsed:
        return "ImUsed";
    case discordpp::HttpStatusCode::MultipleChoices:
        return "MultipleChoices";
    case discordpp::HttpStatusCode::MovedPermanently:
        return "MovedPermanently";
    case discordpp::HttpStatusCode::Found:
        return "Found";
    case discordpp::HttpStatusCode::SeeOther:
        return "SeeOther";
    case discordpp::HttpStatusCode::NotModified:
        return "NotModified";
    case discordpp::HttpStatusCode::TemporaryRedirect:
        return "TemporaryRedirect";
    case discordpp::HttpStatusCode::PermanentRedirect:
        return "PermanentRedirect";
    case discordpp::HttpStatusCode::BadRequest:
        return "BadRequest";
    case discordpp::HttpStatusCode::Unauthorized:
        return "Unauthorized";
    case discordpp::HttpStatusCode::PaymentRequired:
        return "PaymentRequired";
    case discordpp::HttpStatusCode::Forbidden:
        return "Forbidden";
    case discordpp::HttpStatusCode::NotFound:
        return "NotFound";
    case discordpp::HttpStatusCode::MethodNotAllowed:
        return "MethodNotAllowed";
    case discordpp::HttpStatusCode::NotAcceptable:
        return "NotAcceptable";
    case discordpp::HttpStatusCode::ProxyAuthRequired:
        return "ProxyAuthRequired";
    case discordpp::HttpStatusCode::RequestTimeout:
        return "RequestTimeout";
    case discordpp::HttpStatusCode::Conflict:
        return "Conflict";
    case discordpp::HttpStatusCode::Gone:
        return "Gone";
    case discordpp::HttpStatusCode::LengthRequired:
        return "LengthRequired";
    case discordpp::HttpStatusCode::PreconditionFailed:
        return "PreconditionFailed";
    case discordpp::HttpStatusCode::PayloadTooLarge:
        return "PayloadTooLarge";
    case discordpp::HttpStatusCode::UriTooLong:
        return "UriTooLong";
    case discordpp::HttpStatusCode::UnsupportedMediaType:
        return "UnsupportedMediaType";
    case discordpp::HttpStatusCode::RangeNotSatisfiable:
        return "RangeNotSatisfiable";
    case discordpp::HttpStatusCode::ExpectationFailed:
        return "ExpectationFailed";
    case discordpp::HttpStatusCode::MisdirectedRequest:
        return "MisdirectedRequest";
    case discordpp::HttpStatusCode::UnprocessableEntity:
        return "UnprocessableEntity";
    case discordpp::HttpStatusCode::Locked:
        return "Locked";
    case discordpp::HttpStatusCode::FailedDependency:
        return "FailedDependency";
    case discordpp::HttpStatusCode::TooEarly:
        return "TooEarly";
    case discordpp::HttpStatusCode::UpgradeRequired:
        return "UpgradeRequired";
    case discordpp::HttpStatusCode::PreconditionRequired:
        return "PreconditionRequired";
    case discordpp::HttpStatusCode::TooManyRequests:
        return "TooManyRequests";
    case discordpp::HttpStatusCode::RequestHeaderFieldsTooLarge:
        return "RequestHeaderFieldsTooLarge";
    case discordpp::HttpStatusCode::InternalServerError:
        return "InternalServerError";
    case discordpp::HttpStatusCode::NotImplemented:
        return "NotImplemented";
    case discordpp::HttpStatusCode::BadGateway:
        return "BadGateway";
    case discordpp::HttpStatusCode::ServiceUnavailable:
        return "ServiceUnavailable";
    case discordpp::HttpStatusCode::GatewayTimeout:
        return "GatewayTimeout";
    case discordpp::HttpStatusCode::HttpVersionNotSupported:
        return "HttpVersionNotSupported";
    case discordpp::HttpStatusCode::VariantAlsoNegotiates:
        return "VariantAlsoNegotiates";
    case discordpp::HttpStatusCode::InsufficientStorage:
        return "InsufficientStorage";
    case discordpp::HttpStatusCode::LoopDetected:
        return "LoopDetected";
    case discordpp::HttpStatusCode::NotExtended:
        return "NotExtended";
    case discordpp::HttpStatusCode::NetworkAuthorizationRequired:
        return "NetworkAuthorizationRequired";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::AuthenticationCodeChallengeMethod value)
{
    switch (value) {
    case discordpp::AuthenticationCodeChallengeMethod::S256:
        return "S256";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::IntegrationType value)
{
    switch (value) {
    case discordpp::IntegrationType::GuildInstall:
        return "GuildInstall";
    case discordpp::IntegrationType::UserInstall:
        return "UserInstall";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::ChannelType value)
{
    switch (value) {
    case discordpp::ChannelType::GuildText:
        return "GuildText";
    case discordpp::ChannelType::Dm:
        return "Dm";
    case discordpp::ChannelType::GuildVoice:
        return "GuildVoice";
    case discordpp::ChannelType::GroupDm:
        return "GroupDm";
    case discordpp::ChannelType::GuildCategory:
        return "GuildCategory";
    case discordpp::ChannelType::GuildNews:
        return "GuildNews";
    case discordpp::ChannelType::GuildStore:
        return "GuildStore";
    case discordpp::ChannelType::GuildNewsThread:
        return "GuildNewsThread";
    case discordpp::ChannelType::GuildPublicThread:
        return "GuildPublicThread";
    case discordpp::ChannelType::GuildPrivateThread:
        return "GuildPrivateThread";
    case discordpp::ChannelType::GuildStageVoice:
        return "GuildStageVoice";
    case discordpp::ChannelType::GuildDirectory:
        return "GuildDirectory";
    case discordpp::ChannelType::GuildForum:
        return "GuildForum";
    case discordpp::ChannelType::GuildMedia:
        return "GuildMedia";
    case discordpp::ChannelType::Lobby:
        return "Lobby";
    case discordpp::ChannelType::EphemeralDm:
        return "EphemeralDm";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::AdditionalContentType value)
{
    switch (value) {
    case discordpp::AdditionalContentType::Other:
        return "Other";
    case discordpp::AdditionalContentType::Attachment:
        return "Attachment";
    case discordpp::AdditionalContentType::Poll:
        return "Poll";
    case discordpp::AdditionalContentType::VoiceMessage:
        return "VoiceMessage";
    case discordpp::AdditionalContentType::Thread:
        return "Thread";
    case discordpp::AdditionalContentType::Embed:
        return "Embed";
    case discordpp::AdditionalContentType::Sticker:
        return "Sticker";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::VoiceInputModeType value)
{
    switch (value) {
    case discordpp::VoiceInputModeType::VoiceActivity:
        return "VoiceActivity";
    case discordpp::VoiceInputModeType::PushToTalk:
        return "PushToTalk";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::AudioSystem value)
{
    switch (value) {
    case discordpp::AudioSystem::Standard:
        return "Standard";
    case discordpp::AudioSystem::Game:
        return "Game";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::Call::Error value)
{
    switch (value) {
    case discordpp::Call::Error::None:
        return "None";
    case discordpp::Call::Error::SignalingConnectionFailed:
        return "SignalingConnectionFailed";
    case discordpp::Call::Error::SignalingUnexpectedClose:
        return "SignalingUnexpectedClose";
    case discordpp::Call::Error::VoiceConnectionFailed:
        return "VoiceConnectionFailed";
    case discordpp::Call::Error::JoinTimeout:
        return "JoinTimeout";
    case discordpp::Call::Error::Forbidden:
        return "Forbidden";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::AudioModeType value)
{
    switch (value) {
    case discordpp::AudioModeType::MODE_UNINIT:
        return "MODE_UNINIT";
    case discordpp::AudioModeType::MODE_VAD:
        return "MODE_VAD";
    case discordpp::AudioModeType::MODE_PTT:
        return "MODE_PTT";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::Call::Status value)
{
    switch (value) {
    case discordpp::Call::Status::Disconnected:
        return "Disconnected";
    case discordpp::Call::Status::Joining:
        return "Joining";
    case discordpp::Call::Status::Connecting:
        return "Connecting";
    case discordpp::Call::Status::SignalingConnected:
        return "SignalingConnected";
    case discordpp::Call::Status::Connected:
        return "Connected";
    case discordpp::Call::Status::Reconnecting:
        return "Reconnecting";
    case discordpp::Call::Status::Disconnecting:
        return "Disconnecting";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::RelationshipType value)
{
    switch (value) {
    case discordpp::RelationshipType::None:
        return "None";
    case discordpp::RelationshipType::Friend:
        return "Friend";
    case discordpp::RelationshipType::Blocked:
        return "Blocked";
    case discordpp::RelationshipType::PendingIncoming:
        return "PendingIncoming";
    case discordpp::RelationshipType::PendingOutgoing:
        return "PendingOutgoing";
    case discordpp::RelationshipType::Implicit:
        return "Implicit";
    case discordpp::RelationshipType::Suggestion:
        return "Suggestion";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::ExternalIdentityProviderType value)
{
    switch (value) {
    case discordpp::ExternalIdentityProviderType::OIDC:
        return "OIDC";
    case discordpp::ExternalIdentityProviderType::EpicOnlineServices:
        return "EpicOnlineServices";
    case discordpp::ExternalIdentityProviderType::Steam:
        return "Steam";
    case discordpp::ExternalIdentityProviderType::Unity:
        return "Unity";
    case discordpp::ExternalIdentityProviderType::DiscordBot:
        return "DiscordBot";
    case discordpp::ExternalIdentityProviderType::None:
        return "None";
    case discordpp::ExternalIdentityProviderType::Unknown:
        return "Unknown";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::UserHandle::AvatarType value)
{
    switch (value) {
    case discordpp::UserHandle::AvatarType::Gif:
        return "Gif";
    case discordpp::UserHandle::AvatarType::Webp:
        return "Webp";
    case discordpp::UserHandle::AvatarType::Png:
        return "Png";
    case discordpp::UserHandle::AvatarType::Jpeg:
        return "Jpeg";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::StatusType value)
{
    switch (value) {
    case discordpp::StatusType::Online:
        return "Online";
    case discordpp::StatusType::Offline:
        return "Offline";
    case discordpp::StatusType::Blocked:
        return "Blocked";
    case discordpp::StatusType::Idle:
        return "Idle";
    case discordpp::StatusType::Dnd:
        return "Dnd";
    case discordpp::StatusType::Invisible:
        return "Invisible";
    case discordpp::StatusType::Streaming:
        return "Streaming";
    case discordpp::StatusType::Unknown:
        return "Unknown";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::DisclosureTypes value)
{
    switch (value) {
    case discordpp::DisclosureTypes::MessageDataVisibleOnDiscord:
        return "MessageDataVisibleOnDiscord";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::Client::Error value)
{
    switch (value) {
    case discordpp::Client::Error::None:
        return "None";
    case discordpp::Client::Error::ConnectionFailed:
        return "ConnectionFailed";
    case discordpp::Client::Error::UnexpectedClose:
        return "UnexpectedClose";
    case discordpp::Client::Error::ConnectionCanceled:
        return "ConnectionCanceled";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::Client::Status value)
{
    switch (value) {
    case discordpp::Client::Status::Disconnected:
        return "Disconnected";
    case discordpp::Client::Status::Connecting:
        return "Connecting";
    case discordpp::Client::Status::Connected:
        return "Connected";
    case discordpp::Client::Status::Ready:
        return "Ready";
    case discordpp::Client::Status::Reconnecting:
        return "Reconnecting";
    case discordpp::Client::Status::Disconnecting:
        return "Disconnecting";
    case discordpp::Client::Status::HttpWait:
        return "HttpWait";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::Client::Thread value)
{
    switch (value) {
    case discordpp::Client::Thread::Client:
        return "Client";
    case discordpp::Client::Thread::Voice:
        return "Voice";
    case discordpp::Client::Thread::Network:
        return "Network";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::AuthorizationTokenType value)
{
    switch (value) {
    case discordpp::AuthorizationTokenType::User:
        return "User";
    case discordpp::AuthorizationTokenType::Bearer:
        return "Bearer";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::AuthenticationExternalAuthType value)
{
    switch (value) {
    case discordpp::AuthenticationExternalAuthType::OIDC:
        return "OIDC";
    case discordpp::AuthenticationExternalAuthType::EpicOnlineServicesAccessToken:
        return "EpicOnlineServicesAccessToken";
    case discordpp::AuthenticationExternalAuthType::EpicOnlineServicesIdToken:
        return "EpicOnlineServicesIdToken";
    case discordpp::AuthenticationExternalAuthType::SteamSessionTicket:
        return "SteamSessionTicket";
    case discordpp::AuthenticationExternalAuthType::UnityServicesIdToken:
        return "UnityServicesIdToken";
    case discordpp::AuthenticationExternalAuthType::DiscordBotIssuedAccessToken:
        return "DiscordBotIssuedAccessToken";
    case discordpp::AuthenticationExternalAuthType::AppleIdToken:
        return "AppleIdToken";
    case discordpp::AuthenticationExternalAuthType::PlayStationNetworkIdToken:
        return "PlayStationNetworkIdToken";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::LoggingSeverity value)
{
    switch (value) {
    case discordpp::LoggingSeverity::Verbose:
        return "Verbose";
    case discordpp::LoggingSeverity::Info:
        return "Info";
    case discordpp::LoggingSeverity::Warning:
        return "Warning";
    case discordpp::LoggingSeverity::Error:
        return "Error";
    case discordpp::LoggingSeverity::None:
        return "None";
    default:
        return "unknown";
    }
}

inline const char* EnumToString(discordpp::RelationshipGroupType value)
{
    switch (value) {
    case discordpp::RelationshipGroupType::OnlinePlayingGame:
        return "OnlinePlayingGame";
    case discordpp::RelationshipGroupType::OnlineElsewhere:
        return "OnlineElsewhere";
    case discordpp::RelationshipGroupType::Offline:
        return "Offline";
    default:
        return "unknown";
    }
}
}
#endif
#ifdef DISCORDPP_IMPLEMENTATION
#undef DISCORDPP_IMPLEMENTATION
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"
#endif
namespace discordpp {
std::function<void(std::function<void()>)> s_synchronizationContext;

inline bool HasSynchronizationContext()
{
    return !!s_synchronizationContext;
}

inline void PostTask(std::function<void()> task)
{
    assert(s_synchronizationContext);
    s_synchronizationContext(std::move(task));
}

void SetSynchronizationContext(std::function<void(std::function<void()>)> executor)
{
    s_synchronizationContext = std::move(executor);
}

template <typename T>
struct TDelegateUserData {
    T delegate;
    TDelegateUserData(T delegate)
      : delegate{delegate}
    {
    }

    static void Free(void* ptr) { delete reinterpret_cast<TDelegateUserData*>(ptr); }

    static T& Get(void* userData)
    {
        return reinterpret_cast<TDelegateUserData*>(userData)->delegate;
    }
};

struct ConvertedProperties {
    ConvertedProperties(std::unordered_map<std::string, std::string> const& PropertyMap)
    {
        Properties.size = PropertyMap.size();
        Properties.keys = reinterpret_cast<Discord_String*>(
          Discord_Alloc(Properties.size * sizeof(Discord_String)));
        Properties.values = reinterpret_cast<Discord_String*>(
          Discord_Alloc(Properties.size * sizeof(Discord_String)));
        size_t i = 0;
        for (auto& pair : PropertyMap) {
            Properties.keys[i] = AllocateString(pair.first);
            Properties.values[i] = AllocateString(pair.second);
            ++i;
        }
    }
    ~ConvertedProperties() { Discord_FreeProperties(Properties); }
    Discord_Properties Properties{};

private:
    Discord_String AllocateString(std::string const& str)
    {
        Discord_String result;
        result.ptr = reinterpret_cast<uint8_t*>(Discord_Alloc(str.size()));
        result.size = str.size();
        std::memcpy(result.ptr, str.data(), result.size);
        return result;
    }
};

std::unordered_map<std::string, std::string> ConvertReturnedProperties(
  Discord_Properties const& Properties)
{
    std::unordered_map<std::string, std::string> result;
    for (size_t i = 0; i < Properties.size; ++i) {
        std::string key(reinterpret_cast<char*>(Properties.keys[i].ptr), Properties.keys[i].size);
        std::string value(reinterpret_cast<char*>(Properties.values[i].ptr),
                          Properties.values[i].size);
        result.emplace(std::move(key), std::move(value));
    }
    return result;
}
const ActivityInvite ActivityInvite::nullobj{{}, DiscordObjectState::Invalid};
ActivityInvite::~ActivityInvite()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
ActivityInvite::ActivityInvite(ActivityInvite&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
ActivityInvite& ActivityInvite::operator=(ActivityInvite&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
ActivityInvite::ActivityInvite(const ActivityInvite& rhs)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (rhs.state_ == DiscordObjectState::Owned) {
        Discord_ActivityInvite_Clone(&instance_, rhs.instance());

        state_ = DiscordObjectState::Owned;
    }
}
ActivityInvite& ActivityInvite::operator=(const ActivityInvite& rhs)
{
    if (this != &rhs) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (rhs.state_ == DiscordObjectState::Owned) {
            Discord_ActivityInvite_Clone(&instance_, rhs.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
ActivityInvite::ActivityInvite(Discord_ActivityInvite instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
ActivityInvite::ActivityInvite()
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_ActivityInvite_Init(&instance_);
    state_ = DiscordObjectState::Owned;
}
void ActivityInvite::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_ActivityInvite_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
uint64_t ActivityInvite::SenderId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_ActivityInvite_SenderId(&instance_);
    return returnValue__;
}
void ActivityInvite::SetSenderId(uint64_t SenderId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityInvite_SetSenderId(&instance_, SenderId);
}
uint64_t ActivityInvite::ChannelId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_ActivityInvite_ChannelId(&instance_);
    return returnValue__;
}
void ActivityInvite::SetChannelId(uint64_t ChannelId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityInvite_SetChannelId(&instance_, ChannelId);
}
uint64_t ActivityInvite::MessageId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_ActivityInvite_MessageId(&instance_);
    return returnValue__;
}
void ActivityInvite::SetMessageId(uint64_t MessageId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityInvite_SetMessageId(&instance_, MessageId);
}
discordpp::ActivityActionTypes ActivityInvite::Type() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityActionTypes returnValue__;
    returnValue__ = Discord_ActivityInvite_Type(&instance_);
    return static_cast<discordpp::ActivityActionTypes>(returnValue__);
}
void ActivityInvite::SetType(discordpp::ActivityActionTypes Type)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityInvite_SetType(&instance_, static_cast<Discord_ActivityActionTypes>(Type));
}
uint64_t ActivityInvite::ApplicationId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_ActivityInvite_ApplicationId(&instance_);
    return returnValue__;
}
void ActivityInvite::SetApplicationId(uint64_t ApplicationId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityInvite_SetApplicationId(&instance_, ApplicationId);
}
uint64_t ActivityInvite::ParentApplicationId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_ActivityInvite_ParentApplicationId(&instance_);
    return returnValue__;
}
void ActivityInvite::SetParentApplicationId(uint64_t ParentApplicationId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityInvite_SetParentApplicationId(&instance_, ParentApplicationId);
}
std::string ActivityInvite::PartyId() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_ActivityInvite_PartyId(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ActivityInvite::SetPartyId(std::string PartyId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String PartyId__str{(uint8_t*)(PartyId.data()), PartyId.size()};
    Discord_ActivityInvite_SetPartyId(&instance_, PartyId__str);
}
std::string ActivityInvite::SessionId() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_ActivityInvite_SessionId(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ActivityInvite::SetSessionId(std::string SessionId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String SessionId__str{(uint8_t*)(SessionId.data()), SessionId.size()};
    Discord_ActivityInvite_SetSessionId(&instance_, SessionId__str);
}
bool ActivityInvite::IsValid() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_ActivityInvite_IsValid(&instance_);
    return returnValue__;
}
void ActivityInvite::SetIsValid(bool IsValid)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityInvite_SetIsValid(&instance_, IsValid);
}
const ActivityAssets ActivityAssets::nullobj{{}, DiscordObjectState::Invalid};
ActivityAssets::~ActivityAssets()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
ActivityAssets::ActivityAssets(ActivityAssets&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
ActivityAssets& ActivityAssets::operator=(ActivityAssets&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
ActivityAssets::ActivityAssets(const ActivityAssets& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_ActivityAssets_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
ActivityAssets& ActivityAssets::operator=(const ActivityAssets& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_ActivityAssets_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
ActivityAssets::ActivityAssets(Discord_ActivityAssets instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
ActivityAssets::ActivityAssets()
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_ActivityAssets_Init(&instance_);
    state_ = DiscordObjectState::Owned;
}
void ActivityAssets::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_ActivityAssets_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
std::optional<std::string> ActivityAssets::LargeImage() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_ActivityAssets_LargeImage(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ActivityAssets::SetLargeImage(std::optional<std::string> LargeImage)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String LargeImage__str{};
    if (LargeImage.has_value()) {
        LargeImage__str.ptr = reinterpret_cast<uint8_t*>(LargeImage->data());
        LargeImage__str.size = LargeImage->size();
    }
    Discord_ActivityAssets_SetLargeImage(&instance_,
                                         (LargeImage.has_value() ? &LargeImage__str : nullptr));
}
std::optional<std::string> ActivityAssets::LargeText() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_ActivityAssets_LargeText(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ActivityAssets::SetLargeText(std::optional<std::string> LargeText)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String LargeText__str{};
    if (LargeText.has_value()) {
        LargeText__str.ptr = reinterpret_cast<uint8_t*>(LargeText->data());
        LargeText__str.size = LargeText->size();
    }
    Discord_ActivityAssets_SetLargeText(&instance_,
                                        (LargeText.has_value() ? &LargeText__str : nullptr));
}
std::optional<std::string> ActivityAssets::LargeUrl() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_ActivityAssets_LargeUrl(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ActivityAssets::SetLargeUrl(std::optional<std::string> LargeUrl)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String LargeUrl__str{};
    if (LargeUrl.has_value()) {
        LargeUrl__str.ptr = reinterpret_cast<uint8_t*>(LargeUrl->data());
        LargeUrl__str.size = LargeUrl->size();
    }
    Discord_ActivityAssets_SetLargeUrl(&instance_,
                                       (LargeUrl.has_value() ? &LargeUrl__str : nullptr));
}
std::optional<std::string> ActivityAssets::SmallImage() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_ActivityAssets_SmallImage(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ActivityAssets::SetSmallImage(std::optional<std::string> SmallImage)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String SmallImage__str{};
    if (SmallImage.has_value()) {
        SmallImage__str.ptr = reinterpret_cast<uint8_t*>(SmallImage->data());
        SmallImage__str.size = SmallImage->size();
    }
    Discord_ActivityAssets_SetSmallImage(&instance_,
                                         (SmallImage.has_value() ? &SmallImage__str : nullptr));
}
std::optional<std::string> ActivityAssets::SmallText() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_ActivityAssets_SmallText(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ActivityAssets::SetSmallText(std::optional<std::string> SmallText)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String SmallText__str{};
    if (SmallText.has_value()) {
        SmallText__str.ptr = reinterpret_cast<uint8_t*>(SmallText->data());
        SmallText__str.size = SmallText->size();
    }
    Discord_ActivityAssets_SetSmallText(&instance_,
                                        (SmallText.has_value() ? &SmallText__str : nullptr));
}
std::optional<std::string> ActivityAssets::SmallUrl() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_ActivityAssets_SmallUrl(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ActivityAssets::SetSmallUrl(std::optional<std::string> SmallUrl)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String SmallUrl__str{};
    if (SmallUrl.has_value()) {
        SmallUrl__str.ptr = reinterpret_cast<uint8_t*>(SmallUrl->data());
        SmallUrl__str.size = SmallUrl->size();
    }
    Discord_ActivityAssets_SetSmallUrl(&instance_,
                                       (SmallUrl.has_value() ? &SmallUrl__str : nullptr));
}
std::optional<std::string> ActivityAssets::InviteCoverImage() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_ActivityAssets_InviteCoverImage(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ActivityAssets::SetInviteCoverImage(std::optional<std::string> InviteCoverImage)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String InviteCoverImage__str{};
    if (InviteCoverImage.has_value()) {
        InviteCoverImage__str.ptr = reinterpret_cast<uint8_t*>(InviteCoverImage->data());
        InviteCoverImage__str.size = InviteCoverImage->size();
    }
    Discord_ActivityAssets_SetInviteCoverImage(
      &instance_, (InviteCoverImage.has_value() ? &InviteCoverImage__str : nullptr));
}
const ActivityTimestamps ActivityTimestamps::nullobj{{}, DiscordObjectState::Invalid};
ActivityTimestamps::~ActivityTimestamps()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
ActivityTimestamps::ActivityTimestamps(ActivityTimestamps&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
ActivityTimestamps& ActivityTimestamps::operator=(ActivityTimestamps&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
ActivityTimestamps::ActivityTimestamps(const ActivityTimestamps& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_ActivityTimestamps_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
ActivityTimestamps& ActivityTimestamps::operator=(const ActivityTimestamps& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_ActivityTimestamps_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
ActivityTimestamps::ActivityTimestamps(Discord_ActivityTimestamps instance,
                                       DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
ActivityTimestamps::ActivityTimestamps()
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_ActivityTimestamps_Init(&instance_);
    state_ = DiscordObjectState::Owned;
}
void ActivityTimestamps::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_ActivityTimestamps_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
uint64_t ActivityTimestamps::Start() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_ActivityTimestamps_Start(&instance_);
    return returnValue__;
}
void ActivityTimestamps::SetStart(uint64_t Start)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityTimestamps_SetStart(&instance_, Start);
}
uint64_t ActivityTimestamps::End() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_ActivityTimestamps_End(&instance_);
    return returnValue__;
}
void ActivityTimestamps::SetEnd(uint64_t End)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityTimestamps_SetEnd(&instance_, End);
}
const ActivityParty ActivityParty::nullobj{{}, DiscordObjectState::Invalid};
ActivityParty::~ActivityParty()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
ActivityParty::ActivityParty(ActivityParty&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
ActivityParty& ActivityParty::operator=(ActivityParty&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
ActivityParty::ActivityParty(const ActivityParty& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_ActivityParty_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
ActivityParty& ActivityParty::operator=(const ActivityParty& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_ActivityParty_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
ActivityParty::ActivityParty(Discord_ActivityParty instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
ActivityParty::ActivityParty()
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_ActivityParty_Init(&instance_);
    state_ = DiscordObjectState::Owned;
}
void ActivityParty::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_ActivityParty_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
std::string ActivityParty::Id() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_ActivityParty_Id(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ActivityParty::SetId(std::string Id)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Id__str{(uint8_t*)(Id.data()), Id.size()};
    Discord_ActivityParty_SetId(&instance_, Id__str);
}
int32_t ActivityParty::CurrentSize() const
{
    assert(state_ == DiscordObjectState::Owned);
    int32_t returnValue__;
    returnValue__ = Discord_ActivityParty_CurrentSize(&instance_);
    return returnValue__;
}
void ActivityParty::SetCurrentSize(int32_t CurrentSize)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityParty_SetCurrentSize(&instance_, CurrentSize);
}
int32_t ActivityParty::MaxSize() const
{
    assert(state_ == DiscordObjectState::Owned);
    int32_t returnValue__;
    returnValue__ = Discord_ActivityParty_MaxSize(&instance_);
    return returnValue__;
}
void ActivityParty::SetMaxSize(int32_t MaxSize)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityParty_SetMaxSize(&instance_, MaxSize);
}
discordpp::ActivityPartyPrivacy ActivityParty::Privacy() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityPartyPrivacy returnValue__;
    returnValue__ = Discord_ActivityParty_Privacy(&instance_);
    return static_cast<discordpp::ActivityPartyPrivacy>(returnValue__);
}
void ActivityParty::SetPrivacy(discordpp::ActivityPartyPrivacy Privacy)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityParty_SetPrivacy(&instance_,
                                     static_cast<Discord_ActivityPartyPrivacy>(Privacy));
}
const ActivitySecrets ActivitySecrets::nullobj{{}, DiscordObjectState::Invalid};
ActivitySecrets::~ActivitySecrets()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
ActivitySecrets::ActivitySecrets(ActivitySecrets&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
ActivitySecrets& ActivitySecrets::operator=(ActivitySecrets&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
ActivitySecrets::ActivitySecrets(const ActivitySecrets& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_ActivitySecrets_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
ActivitySecrets& ActivitySecrets::operator=(const ActivitySecrets& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_ActivitySecrets_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
ActivitySecrets::ActivitySecrets(Discord_ActivitySecrets instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
ActivitySecrets::ActivitySecrets()
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_ActivitySecrets_Init(&instance_);
    state_ = DiscordObjectState::Owned;
}
void ActivitySecrets::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_ActivitySecrets_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
std::string ActivitySecrets::Join() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_ActivitySecrets_Join(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ActivitySecrets::SetJoin(std::string Join)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Join__str{(uint8_t*)(Join.data()), Join.size()};
    Discord_ActivitySecrets_SetJoin(&instance_, Join__str);
}
const ActivityButton ActivityButton::nullobj{{}, DiscordObjectState::Invalid};
ActivityButton::~ActivityButton()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
ActivityButton::ActivityButton(ActivityButton&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
ActivityButton& ActivityButton::operator=(ActivityButton&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
ActivityButton::ActivityButton(const ActivityButton& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_ActivityButton_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
ActivityButton& ActivityButton::operator=(const ActivityButton& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_ActivityButton_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
ActivityButton::ActivityButton(Discord_ActivityButton instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
ActivityButton::ActivityButton()
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_ActivityButton_Init(&instance_);
    state_ = DiscordObjectState::Owned;
}
void ActivityButton::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_ActivityButton_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
std::string ActivityButton::Label() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_ActivityButton_Label(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ActivityButton::SetLabel(std::string Label)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Label__str{(uint8_t*)(Label.data()), Label.size()};
    Discord_ActivityButton_SetLabel(&instance_, Label__str);
}
std::string ActivityButton::Url() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_ActivityButton_Url(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ActivityButton::SetUrl(std::string Url)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Url__str{(uint8_t*)(Url.data()), Url.size()};
    Discord_ActivityButton_SetUrl(&instance_, Url__str);
}
const Activity Activity::nullobj{{}, DiscordObjectState::Invalid};
Activity::~Activity()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
Activity::Activity(Activity&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
Activity& Activity::operator=(Activity&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
Activity::Activity(const Activity& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_Activity_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
Activity& Activity::operator=(const Activity& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_Activity_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
Activity::Activity(Discord_Activity instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
Activity::Activity()
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_Activity_Init(&instance_);
    state_ = DiscordObjectState::Owned;
}
void Activity::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_Activity_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
void Activity::AddButton(discordpp::ActivityButton button)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Activity_AddButton(&instance_, button.instance());
}
bool Activity::Equals(discordpp::Activity other) const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_Activity_Equals(&instance_, other.instance());
    return returnValue__;
}
std::vector<discordpp::ActivityButton> Activity::GetButtons() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityButtonSpan returnValueNative__;
    Discord_Activity_GetButtons(&instance_, &returnValueNative__);
    std::vector<discordpp::ActivityButton> returnValue__;
    returnValue__.reserve(returnValueNative__.size);
    for (size_t i__ = 0; i__ < returnValueNative__.size; ++i__) {
        returnValue__.emplace_back(returnValueNative__.ptr[i__], DiscordObjectState::Owned);
    }
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::string Activity::Name() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_Activity_Name(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void Activity::SetName(std::string Name)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Name__str{(uint8_t*)(Name.data()), Name.size()};
    Discord_Activity_SetName(&instance_, Name__str);
}
discordpp::ActivityTypes Activity::Type() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityTypes returnValue__;
    returnValue__ = Discord_Activity_Type(&instance_);
    return static_cast<discordpp::ActivityTypes>(returnValue__);
}
void Activity::SetType(discordpp::ActivityTypes Type)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Activity_SetType(&instance_, static_cast<Discord_ActivityTypes>(Type));
}
std::optional<discordpp::StatusDisplayTypes> Activity::StatusDisplayType() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_StatusDisplayTypes returnValueNative__;
    returnIsNonNull__ = Discord_Activity_StatusDisplayType(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    auto returnValue__ = static_cast<discordpp::StatusDisplayTypes>(returnValueNative__);
    return returnValue__;
}
void Activity::SetStatusDisplayType(std::optional<discordpp::StatusDisplayTypes> StatusDisplayType)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Activity_SetStatusDisplayType(
      &instance_,
      (StatusDisplayType.has_value()
         ? reinterpret_cast<Discord_StatusDisplayTypes*>(&*StatusDisplayType)
         : nullptr));
}
std::optional<std::string> Activity::State() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_Activity_State(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void Activity::SetState(std::optional<std::string> State)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String State__str{};
    if (State.has_value()) {
        State__str.ptr = reinterpret_cast<uint8_t*>(State->data());
        State__str.size = State->size();
    }
    Discord_Activity_SetState(&instance_, (State.has_value() ? &State__str : nullptr));
}
std::optional<std::string> Activity::StateUrl() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_Activity_StateUrl(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void Activity::SetStateUrl(std::optional<std::string> StateUrl)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String StateUrl__str{};
    if (StateUrl.has_value()) {
        StateUrl__str.ptr = reinterpret_cast<uint8_t*>(StateUrl->data());
        StateUrl__str.size = StateUrl->size();
    }
    Discord_Activity_SetStateUrl(&instance_, (StateUrl.has_value() ? &StateUrl__str : nullptr));
}
std::optional<std::string> Activity::Details() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_Activity_Details(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void Activity::SetDetails(std::optional<std::string> Details)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Details__str{};
    if (Details.has_value()) {
        Details__str.ptr = reinterpret_cast<uint8_t*>(Details->data());
        Details__str.size = Details->size();
    }
    Discord_Activity_SetDetails(&instance_, (Details.has_value() ? &Details__str : nullptr));
}
std::optional<std::string> Activity::DetailsUrl() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_Activity_DetailsUrl(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void Activity::SetDetailsUrl(std::optional<std::string> DetailsUrl)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String DetailsUrl__str{};
    if (DetailsUrl.has_value()) {
        DetailsUrl__str.ptr = reinterpret_cast<uint8_t*>(DetailsUrl->data());
        DetailsUrl__str.size = DetailsUrl->size();
    }
    Discord_Activity_SetDetailsUrl(&instance_,
                                   (DetailsUrl.has_value() ? &DetailsUrl__str : nullptr));
}
std::optional<uint64_t> Activity::ApplicationId() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    uint64_t returnValue__;
    returnIsNonNull__ = Discord_Activity_ApplicationId(&instance_, &returnValue__);
    if (!returnIsNonNull__) {
        return std::nullopt;
    }
    return returnValue__;
}
void Activity::SetApplicationId(std::optional<uint64_t> ApplicationId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Activity_SetApplicationId(&instance_,
                                      (ApplicationId.has_value() ? &*ApplicationId : nullptr));
}
std::optional<uint64_t> Activity::ParentApplicationId() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    uint64_t returnValue__;
    returnIsNonNull__ = Discord_Activity_ParentApplicationId(&instance_, &returnValue__);
    if (!returnIsNonNull__) {
        return std::nullopt;
    }
    return returnValue__;
}
void Activity::SetParentApplicationId(std::optional<uint64_t> ParentApplicationId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Activity_SetParentApplicationId(
      &instance_, (ParentApplicationId.has_value() ? &*ParentApplicationId : nullptr));
}
std::optional<discordpp::ActivityAssets> Activity::Assets() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_ActivityAssets returnValueNative__;
    returnIsNonNull__ = Discord_Activity_Assets(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::ActivityAssets returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
void Activity::SetAssets(std::optional<discordpp::ActivityAssets> Assets)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Activity_SetAssets(&instance_, (Assets.has_value() ? Assets->instance() : nullptr));
}
std::optional<discordpp::ActivityTimestamps> Activity::Timestamps() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_ActivityTimestamps returnValueNative__;
    returnIsNonNull__ = Discord_Activity_Timestamps(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::ActivityTimestamps returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
void Activity::SetTimestamps(std::optional<discordpp::ActivityTimestamps> Timestamps)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Activity_SetTimestamps(&instance_,
                                   (Timestamps.has_value() ? Timestamps->instance() : nullptr));
}
std::optional<discordpp::ActivityParty> Activity::Party() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_ActivityParty returnValueNative__;
    returnIsNonNull__ = Discord_Activity_Party(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::ActivityParty returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
void Activity::SetParty(std::optional<discordpp::ActivityParty> Party)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Activity_SetParty(&instance_, (Party.has_value() ? Party->instance() : nullptr));
}
std::optional<discordpp::ActivitySecrets> Activity::Secrets() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_ActivitySecrets returnValueNative__;
    returnIsNonNull__ = Discord_Activity_Secrets(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::ActivitySecrets returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
void Activity::SetSecrets(std::optional<discordpp::ActivitySecrets> Secrets)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Activity_SetSecrets(&instance_, (Secrets.has_value() ? Secrets->instance() : nullptr));
}
discordpp::ActivityGamePlatforms Activity::SupportedPlatforms() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ActivityGamePlatforms returnValue__;
    returnValue__ = Discord_Activity_SupportedPlatforms(&instance_);
    return static_cast<discordpp::ActivityGamePlatforms>(returnValue__);
}
void Activity::SetSupportedPlatforms(discordpp::ActivityGamePlatforms SupportedPlatforms)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Activity_SetSupportedPlatforms(
      &instance_, static_cast<Discord_ActivityGamePlatforms>(SupportedPlatforms));
}
const ClientResult ClientResult::nullobj{{}, DiscordObjectState::Invalid};
ClientResult::~ClientResult()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
ClientResult::ClientResult(ClientResult&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
ClientResult& ClientResult::operator=(ClientResult&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
ClientResult::ClientResult(const ClientResult& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_ClientResult_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
ClientResult& ClientResult::operator=(const ClientResult& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_ClientResult_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
ClientResult::ClientResult(Discord_ClientResult instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void ClientResult::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_ClientResult_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
std::string ClientResult::ToString() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_ClientResult_ToString(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
discordpp::ErrorType ClientResult::Type() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ErrorType returnValue__;
    returnValue__ = Discord_ClientResult_Type(&instance_);
    return static_cast<discordpp::ErrorType>(returnValue__);
}
void ClientResult::SetType(discordpp::ErrorType Type)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ClientResult_SetType(&instance_, static_cast<Discord_ErrorType>(Type));
}
std::string ClientResult::Error() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_ClientResult_Error(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ClientResult::SetError(std::string Error)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Error__str{(uint8_t*)(Error.data()), Error.size()};
    Discord_ClientResult_SetError(&instance_, Error__str);
}
int32_t ClientResult::ErrorCode() const
{
    assert(state_ == DiscordObjectState::Owned);
    int32_t returnValue__;
    returnValue__ = Discord_ClientResult_ErrorCode(&instance_);
    return returnValue__;
}
void ClientResult::SetErrorCode(int32_t ErrorCode)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ClientResult_SetErrorCode(&instance_, ErrorCode);
}
discordpp::HttpStatusCode ClientResult::Status() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_HttpStatusCode returnValue__;
    returnValue__ = Discord_ClientResult_Status(&instance_);
    return static_cast<discordpp::HttpStatusCode>(returnValue__);
}
void ClientResult::SetStatus(discordpp::HttpStatusCode Status)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ClientResult_SetStatus(&instance_, static_cast<Discord_HttpStatusCode>(Status));
}
std::string ClientResult::ResponseBody() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_ClientResult_ResponseBody(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ClientResult::SetResponseBody(std::string ResponseBody)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String ResponseBody__str{(uint8_t*)(ResponseBody.data()), ResponseBody.size()};
    Discord_ClientResult_SetResponseBody(&instance_, ResponseBody__str);
}
bool ClientResult::Successful() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_ClientResult_Successful(&instance_);
    return returnValue__;
}
void ClientResult::SetSuccessful(bool Successful)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ClientResult_SetSuccessful(&instance_, Successful);
}
bool ClientResult::Retryable() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_ClientResult_Retryable(&instance_);
    return returnValue__;
}
void ClientResult::SetRetryable(bool Retryable)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ClientResult_SetRetryable(&instance_, Retryable);
}
float ClientResult::RetryAfter() const
{
    assert(state_ == DiscordObjectState::Owned);
    float returnValue__;
    returnValue__ = Discord_ClientResult_RetryAfter(&instance_);
    return returnValue__;
}
void ClientResult::SetRetryAfter(float RetryAfter)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ClientResult_SetRetryAfter(&instance_, RetryAfter);
}
const AuthorizationCodeChallenge AuthorizationCodeChallenge::nullobj{{},
                                                                     DiscordObjectState::Invalid};
AuthorizationCodeChallenge::~AuthorizationCodeChallenge()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
AuthorizationCodeChallenge::AuthorizationCodeChallenge(AuthorizationCodeChallenge&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
AuthorizationCodeChallenge& AuthorizationCodeChallenge::operator=(
  AuthorizationCodeChallenge&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
AuthorizationCodeChallenge::AuthorizationCodeChallenge(const AuthorizationCodeChallenge& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_AuthorizationCodeChallenge_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
AuthorizationCodeChallenge& AuthorizationCodeChallenge::operator=(
  const AuthorizationCodeChallenge& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_AuthorizationCodeChallenge_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
AuthorizationCodeChallenge::AuthorizationCodeChallenge(Discord_AuthorizationCodeChallenge instance,
                                                       DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
AuthorizationCodeChallenge::AuthorizationCodeChallenge()
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_AuthorizationCodeChallenge_Init(&instance_);
    state_ = DiscordObjectState::Owned;
}
void AuthorizationCodeChallenge::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_AuthorizationCodeChallenge_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
discordpp::AuthenticationCodeChallengeMethod AuthorizationCodeChallenge::Method() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_AuthenticationCodeChallengeMethod returnValue__;
    returnValue__ = Discord_AuthorizationCodeChallenge_Method(&instance_);
    return static_cast<discordpp::AuthenticationCodeChallengeMethod>(returnValue__);
}
void AuthorizationCodeChallenge::SetMethod(discordpp::AuthenticationCodeChallengeMethod Method)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_AuthorizationCodeChallenge_SetMethod(
      &instance_, static_cast<Discord_AuthenticationCodeChallengeMethod>(Method));
}
std::string AuthorizationCodeChallenge::Challenge() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_AuthorizationCodeChallenge_Challenge(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void AuthorizationCodeChallenge::SetChallenge(std::string Challenge)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Challenge__str{(uint8_t*)(Challenge.data()), Challenge.size()};
    Discord_AuthorizationCodeChallenge_SetChallenge(&instance_, Challenge__str);
}
const AuthorizationCodeVerifier AuthorizationCodeVerifier::nullobj{{}, DiscordObjectState::Invalid};
AuthorizationCodeVerifier::~AuthorizationCodeVerifier()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
AuthorizationCodeVerifier::AuthorizationCodeVerifier(AuthorizationCodeVerifier&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
AuthorizationCodeVerifier& AuthorizationCodeVerifier::operator=(
  AuthorizationCodeVerifier&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
AuthorizationCodeVerifier::AuthorizationCodeVerifier(const AuthorizationCodeVerifier& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_AuthorizationCodeVerifier_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
AuthorizationCodeVerifier& AuthorizationCodeVerifier::operator=(
  const AuthorizationCodeVerifier& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_AuthorizationCodeVerifier_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
AuthorizationCodeVerifier::AuthorizationCodeVerifier(Discord_AuthorizationCodeVerifier instance,
                                                     DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void AuthorizationCodeVerifier::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_AuthorizationCodeVerifier_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
discordpp::AuthorizationCodeChallenge AuthorizationCodeVerifier::Challenge() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_AuthorizationCodeChallenge returnValueNative__{};
    Discord_AuthorizationCodeVerifier_Challenge(&instance_, &returnValueNative__);
    discordpp::AuthorizationCodeChallenge returnValue__(returnValueNative__,
                                                        DiscordObjectState::Owned);
    return returnValue__;
}
void AuthorizationCodeVerifier::SetChallenge(discordpp::AuthorizationCodeChallenge Challenge)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_AuthorizationCodeVerifier_SetChallenge(&instance_, Challenge.instance());
}
std::string AuthorizationCodeVerifier::Verifier() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_AuthorizationCodeVerifier_Verifier(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void AuthorizationCodeVerifier::SetVerifier(std::string Verifier)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Verifier__str{(uint8_t*)(Verifier.data()), Verifier.size()};
    Discord_AuthorizationCodeVerifier_SetVerifier(&instance_, Verifier__str);
}
const AuthorizationArgs AuthorizationArgs::nullobj{{}, DiscordObjectState::Invalid};
AuthorizationArgs::~AuthorizationArgs()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
AuthorizationArgs::AuthorizationArgs(AuthorizationArgs&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
AuthorizationArgs& AuthorizationArgs::operator=(AuthorizationArgs&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
AuthorizationArgs::AuthorizationArgs(const AuthorizationArgs& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_AuthorizationArgs_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
AuthorizationArgs& AuthorizationArgs::operator=(const AuthorizationArgs& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_AuthorizationArgs_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
AuthorizationArgs::AuthorizationArgs(Discord_AuthorizationArgs instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
AuthorizationArgs::AuthorizationArgs()
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_AuthorizationArgs_Init(&instance_);
    state_ = DiscordObjectState::Owned;
}
void AuthorizationArgs::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_AuthorizationArgs_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
uint64_t AuthorizationArgs::ClientId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_AuthorizationArgs_ClientId(&instance_);
    return returnValue__;
}
void AuthorizationArgs::SetClientId(uint64_t ClientId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_AuthorizationArgs_SetClientId(&instance_, ClientId);
}
std::string AuthorizationArgs::Scopes() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_AuthorizationArgs_Scopes(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void AuthorizationArgs::SetScopes(std::string Scopes)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Scopes__str{(uint8_t*)(Scopes.data()), Scopes.size()};
    Discord_AuthorizationArgs_SetScopes(&instance_, Scopes__str);
}
std::optional<std::string> AuthorizationArgs::State() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_AuthorizationArgs_State(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void AuthorizationArgs::SetState(std::optional<std::string> State)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String State__str{};
    if (State.has_value()) {
        State__str.ptr = reinterpret_cast<uint8_t*>(State->data());
        State__str.size = State->size();
    }
    Discord_AuthorizationArgs_SetState(&instance_, (State.has_value() ? &State__str : nullptr));
}
std::optional<std::string> AuthorizationArgs::Nonce() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_AuthorizationArgs_Nonce(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void AuthorizationArgs::SetNonce(std::optional<std::string> Nonce)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Nonce__str{};
    if (Nonce.has_value()) {
        Nonce__str.ptr = reinterpret_cast<uint8_t*>(Nonce->data());
        Nonce__str.size = Nonce->size();
    }
    Discord_AuthorizationArgs_SetNonce(&instance_, (Nonce.has_value() ? &Nonce__str : nullptr));
}
std::optional<discordpp::AuthorizationCodeChallenge> AuthorizationArgs::CodeChallenge() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_AuthorizationCodeChallenge returnValueNative__;
    returnIsNonNull__ = Discord_AuthorizationArgs_CodeChallenge(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::AuthorizationCodeChallenge returnValue__(returnValueNative__,
                                                        DiscordObjectState::Owned);
    return returnValue__;
}
void AuthorizationArgs::SetCodeChallenge(
  std::optional<discordpp::AuthorizationCodeChallenge> CodeChallenge)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_AuthorizationArgs_SetCodeChallenge(
      &instance_, (CodeChallenge.has_value() ? CodeChallenge->instance() : nullptr));
}
std::optional<discordpp::IntegrationType> AuthorizationArgs::IntegrationType() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_IntegrationType returnValueNative__;
    returnIsNonNull__ = Discord_AuthorizationArgs_IntegrationType(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    auto returnValue__ = static_cast<discordpp::IntegrationType>(returnValueNative__);
    return returnValue__;
}
void AuthorizationArgs::SetIntegrationType(
  std::optional<discordpp::IntegrationType> IntegrationType)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_AuthorizationArgs_SetIntegrationType(
      &instance_,
      (IntegrationType.has_value() ? reinterpret_cast<Discord_IntegrationType*>(&*IntegrationType)
                                   : nullptr));
}
std::optional<std::string> AuthorizationArgs::CustomSchemeParam() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ =
      Discord_AuthorizationArgs_CustomSchemeParam(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void AuthorizationArgs::SetCustomSchemeParam(std::optional<std::string> CustomSchemeParam)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String CustomSchemeParam__str{};
    if (CustomSchemeParam.has_value()) {
        CustomSchemeParam__str.ptr = reinterpret_cast<uint8_t*>(CustomSchemeParam->data());
        CustomSchemeParam__str.size = CustomSchemeParam->size();
    }
    Discord_AuthorizationArgs_SetCustomSchemeParam(
      &instance_, (CustomSchemeParam.has_value() ? &CustomSchemeParam__str : nullptr));
}
const DeviceAuthorizationArgs DeviceAuthorizationArgs::nullobj{{}, DiscordObjectState::Invalid};
DeviceAuthorizationArgs::~DeviceAuthorizationArgs()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
DeviceAuthorizationArgs::DeviceAuthorizationArgs(DeviceAuthorizationArgs&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
DeviceAuthorizationArgs& DeviceAuthorizationArgs::operator=(
  DeviceAuthorizationArgs&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
DeviceAuthorizationArgs::DeviceAuthorizationArgs(const DeviceAuthorizationArgs& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_DeviceAuthorizationArgs_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
DeviceAuthorizationArgs& DeviceAuthorizationArgs::operator=(const DeviceAuthorizationArgs& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_DeviceAuthorizationArgs_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
DeviceAuthorizationArgs::DeviceAuthorizationArgs(Discord_DeviceAuthorizationArgs instance,
                                                 DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
DeviceAuthorizationArgs::DeviceAuthorizationArgs()
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_DeviceAuthorizationArgs_Init(&instance_);
    state_ = DiscordObjectState::Owned;
}
void DeviceAuthorizationArgs::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_DeviceAuthorizationArgs_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
uint64_t DeviceAuthorizationArgs::ClientId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_DeviceAuthorizationArgs_ClientId(&instance_);
    return returnValue__;
}
void DeviceAuthorizationArgs::SetClientId(uint64_t ClientId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_DeviceAuthorizationArgs_SetClientId(&instance_, ClientId);
}
std::string DeviceAuthorizationArgs::Scopes() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_DeviceAuthorizationArgs_Scopes(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void DeviceAuthorizationArgs::SetScopes(std::string Scopes)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Scopes__str{(uint8_t*)(Scopes.data()), Scopes.size()};
    Discord_DeviceAuthorizationArgs_SetScopes(&instance_, Scopes__str);
}
const VoiceStateHandle VoiceStateHandle::nullobj{{}, DiscordObjectState::Invalid};
VoiceStateHandle::~VoiceStateHandle()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
VoiceStateHandle::VoiceStateHandle(VoiceStateHandle&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
VoiceStateHandle& VoiceStateHandle::operator=(VoiceStateHandle&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
VoiceStateHandle::VoiceStateHandle(const VoiceStateHandle& other)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (other.state_ == DiscordObjectState::Owned) {
        Discord_VoiceStateHandle_Clone(&instance_, other.instance());

        state_ = DiscordObjectState::Owned;
    }
}
VoiceStateHandle& VoiceStateHandle::operator=(const VoiceStateHandle& other)
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (other.state_ == DiscordObjectState::Owned) {
            Discord_VoiceStateHandle_Clone(&instance_, other.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
VoiceStateHandle::VoiceStateHandle(Discord_VoiceStateHandle instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void VoiceStateHandle::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_VoiceStateHandle_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
bool VoiceStateHandle::SelfDeaf() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_VoiceStateHandle_SelfDeaf(&instance_);
    return returnValue__;
}
bool VoiceStateHandle::SelfMute() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_VoiceStateHandle_SelfMute(&instance_);
    return returnValue__;
}
const VADThresholdSettings VADThresholdSettings::nullobj{{}, DiscordObjectState::Invalid};
VADThresholdSettings::~VADThresholdSettings()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
VADThresholdSettings::VADThresholdSettings(VADThresholdSettings&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
VADThresholdSettings& VADThresholdSettings::operator=(VADThresholdSettings&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
VADThresholdSettings::VADThresholdSettings(Discord_VADThresholdSettings instance,
                                           DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void VADThresholdSettings::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_VADThresholdSettings_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
float VADThresholdSettings::VadThreshold() const
{
    assert(state_ == DiscordObjectState::Owned);
    float returnValue__;
    returnValue__ = Discord_VADThresholdSettings_VadThreshold(&instance_);
    return returnValue__;
}
void VADThresholdSettings::SetVadThreshold(float VadThreshold)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_VADThresholdSettings_SetVadThreshold(&instance_, VadThreshold);
}
bool VADThresholdSettings::Automatic() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_VADThresholdSettings_Automatic(&instance_);
    return returnValue__;
}
void VADThresholdSettings::SetAutomatic(bool Automatic)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_VADThresholdSettings_SetAutomatic(&instance_, Automatic);
}
const Call Call::nullobj{{}, DiscordObjectState::Invalid};
Call::~Call()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
Call::Call(Call&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
Call& Call::operator=(Call&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
Call::Call(const Call& other)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (other.state_ == DiscordObjectState::Owned) {
        Discord_Call_Clone(&instance_, other.instance());

        state_ = DiscordObjectState::Owned;
    }
}
Call& Call::operator=(const Call& other)
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (other.state_ == DiscordObjectState::Owned) {
            Discord_Call_Clone(&instance_, other.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
Call::Call(Discord_Call instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void Call::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_Call_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
std::string Call::ErrorToString(discordpp::Call::Error type)
{
    Discord_String returnValueNative__;
    Discord_Call_ErrorToString(static_cast<Discord_Call_Error>(type), &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
discordpp::AudioModeType Call::GetAudioMode()
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_AudioModeType returnValue__;
    returnValue__ = Discord_Call_GetAudioMode(&instance_);
    return static_cast<discordpp::AudioModeType>(returnValue__);
}
uint64_t Call::GetChannelId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_Call_GetChannelId(&instance_);
    return returnValue__;
}
uint64_t Call::GetGuildId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_Call_GetGuildId(&instance_);
    return returnValue__;
}
bool Call::GetLocalMute(uint64_t userId)
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_Call_GetLocalMute(&instance_, userId);
    return returnValue__;
}
std::vector<uint64_t> Call::GetParticipants() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_UInt64Span returnValueNative__;
    Discord_Call_GetParticipants(&instance_, &returnValueNative__);
    std::vector<uint64_t> returnValue__(returnValueNative__.ptr,
                                        returnValueNative__.ptr + returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
float Call::GetParticipantVolume(uint64_t userId)
{
    assert(state_ == DiscordObjectState::Owned);
    float returnValue__;
    returnValue__ = Discord_Call_GetParticipantVolume(&instance_, userId);
    return returnValue__;
}
bool Call::GetPTTActive()
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_Call_GetPTTActive(&instance_);
    return returnValue__;
}
uint32_t Call::GetPTTReleaseDelay()
{
    assert(state_ == DiscordObjectState::Owned);
    uint32_t returnValue__;
    returnValue__ = Discord_Call_GetPTTReleaseDelay(&instance_);
    return returnValue__;
}
bool Call::GetSelfDeaf()
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_Call_GetSelfDeaf(&instance_);
    return returnValue__;
}
bool Call::GetSelfMute()
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_Call_GetSelfMute(&instance_);
    return returnValue__;
}
discordpp::Call::Status Call::GetStatus() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Call_Status returnValue__;
    returnValue__ = Discord_Call_GetStatus(&instance_);
    return static_cast<discordpp::Call::Status>(returnValue__);
}
discordpp::VADThresholdSettings Call::GetVADThreshold() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_VADThresholdSettings returnValueNative__{};
    Discord_Call_GetVADThreshold(&instance_, &returnValueNative__);
    discordpp::VADThresholdSettings returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
std::optional<discordpp::VoiceStateHandle> Call::GetVoiceStateHandle(uint64_t userId) const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_VoiceStateHandle returnValueNative__;
    returnIsNonNull__ = Discord_Call_GetVoiceStateHandle(&instance_, userId, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::VoiceStateHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
void Call::SetAudioMode(discordpp::AudioModeType audioMode)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Call_SetAudioMode(&instance_, static_cast<Discord_AudioModeType>(audioMode));
}
void Call::SetLocalMute(uint64_t userId, bool mute)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Call_SetLocalMute(&instance_, userId, mute);
}
void Call::SetOnVoiceStateChangedCallback(discordpp::Call::OnVoiceStateChanged cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Call_OnVoiceStateChanged cb__native = [](auto userId, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        userData__typed->delegate(userId);
    };
    Discord_Call_SetOnVoiceStateChangedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Call::SetParticipantChangedCallback(discordpp::Call::OnParticipantChanged cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Call_OnParticipantChanged cb__native = [](auto userId, auto added, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        userData__typed->delegate(userId, added);
    };
    Discord_Call_SetParticipantChangedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Call::SetParticipantVolume(uint64_t userId, float volume)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Call_SetParticipantVolume(&instance_, userId, volume);
}
void Call::SetPTTActive(bool active)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Call_SetPTTActive(&instance_, active);
}
void Call::SetPTTReleaseDelay(uint32_t releaseDelayMs)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Call_SetPTTReleaseDelay(&instance_, releaseDelayMs);
}
void Call::SetSelfDeaf(bool deaf)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Call_SetSelfDeaf(&instance_, deaf);
}
void Call::SetSelfMute(bool mute)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Call_SetSelfMute(&instance_, mute);
}
void Call::SetSpeakingStatusChangedCallback(discordpp::Call::OnSpeakingStatusChanged cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Call_OnSpeakingStatusChanged cb__native =
      [](auto userId, auto isPlayingSound, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          userData__typed->delegate(userId, isPlayingSound);
      };
    Discord_Call_SetSpeakingStatusChangedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Call::SetStatusChangedCallback(discordpp::Call::OnStatusChanged cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Call_OnStatusChanged cb__native =
      [](auto status, auto error, auto errorDetail, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          userData__typed->delegate(static_cast<discordpp::Call::Status>(status),
                                    static_cast<discordpp::Call::Error>(error),
                                    errorDetail);
      };
    Discord_Call_SetStatusChangedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Call::SetVADThreshold(bool automatic, float threshold)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Call_SetVADThreshold(&instance_, automatic, threshold);
}
std::string Call::StatusToString(discordpp::Call::Status type)
{
    Discord_String returnValueNative__;
    Discord_Call_StatusToString(static_cast<Discord_Call_Status>(type), &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
const ChannelHandle ChannelHandle::nullobj{{}, DiscordObjectState::Invalid};
ChannelHandle::~ChannelHandle()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
ChannelHandle::ChannelHandle(ChannelHandle&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
ChannelHandle& ChannelHandle::operator=(ChannelHandle&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
ChannelHandle::ChannelHandle(const ChannelHandle& other)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (other.state_ == DiscordObjectState::Owned) {
        Discord_ChannelHandle_Clone(&instance_, other.instance());

        state_ = DiscordObjectState::Owned;
    }
}
ChannelHandle& ChannelHandle::operator=(const ChannelHandle& other)
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (other.state_ == DiscordObjectState::Owned) {
            Discord_ChannelHandle_Clone(&instance_, other.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
ChannelHandle::ChannelHandle(Discord_ChannelHandle instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void ChannelHandle::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_ChannelHandle_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
uint64_t ChannelHandle::Id() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_ChannelHandle_Id(&instance_);
    return returnValue__;
}
std::string ChannelHandle::Name() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_ChannelHandle_Name(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::vector<uint64_t> ChannelHandle::Recipients() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_UInt64Span returnValueNative__;
    Discord_ChannelHandle_Recipients(&instance_, &returnValueNative__);
    std::vector<uint64_t> returnValue__(returnValueNative__.ptr,
                                        returnValueNative__.ptr + returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
discordpp::ChannelType ChannelHandle::Type() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ChannelType returnValue__;
    returnValue__ = Discord_ChannelHandle_Type(&instance_);
    return static_cast<discordpp::ChannelType>(returnValue__);
}
const GuildMinimal GuildMinimal::nullobj{{}, DiscordObjectState::Invalid};
GuildMinimal::~GuildMinimal()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
GuildMinimal::GuildMinimal(GuildMinimal&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
GuildMinimal& GuildMinimal::operator=(GuildMinimal&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
GuildMinimal::GuildMinimal(const GuildMinimal& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_GuildMinimal_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
GuildMinimal& GuildMinimal::operator=(const GuildMinimal& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_GuildMinimal_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
GuildMinimal::GuildMinimal(Discord_GuildMinimal instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void GuildMinimal::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_GuildMinimal_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
uint64_t GuildMinimal::Id() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_GuildMinimal_Id(&instance_);
    return returnValue__;
}
void GuildMinimal::SetId(uint64_t Id)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_GuildMinimal_SetId(&instance_, Id);
}
std::string GuildMinimal::Name() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_GuildMinimal_Name(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void GuildMinimal::SetName(std::string Name)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Name__str{(uint8_t*)(Name.data()), Name.size()};
    Discord_GuildMinimal_SetName(&instance_, Name__str);
}
const GuildChannel GuildChannel::nullobj{{}, DiscordObjectState::Invalid};
GuildChannel::~GuildChannel()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
GuildChannel::GuildChannel(GuildChannel&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
GuildChannel& GuildChannel::operator=(GuildChannel&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
GuildChannel::GuildChannel(const GuildChannel& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_GuildChannel_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
GuildChannel& GuildChannel::operator=(const GuildChannel& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_GuildChannel_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
GuildChannel::GuildChannel(Discord_GuildChannel instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void GuildChannel::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_GuildChannel_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
uint64_t GuildChannel::Id() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_GuildChannel_Id(&instance_);
    return returnValue__;
}
void GuildChannel::SetId(uint64_t Id)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_GuildChannel_SetId(&instance_, Id);
}
std::string GuildChannel::Name() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_GuildChannel_Name(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void GuildChannel::SetName(std::string Name)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Name__str{(uint8_t*)(Name.data()), Name.size()};
    Discord_GuildChannel_SetName(&instance_, Name__str);
}
discordpp::ChannelType GuildChannel::Type() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ChannelType returnValue__;
    returnValue__ = Discord_GuildChannel_Type(&instance_);
    return static_cast<discordpp::ChannelType>(returnValue__);
}
void GuildChannel::SetType(discordpp::ChannelType Type)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_GuildChannel_SetType(&instance_, static_cast<Discord_ChannelType>(Type));
}
int32_t GuildChannel::Position() const
{
    assert(state_ == DiscordObjectState::Owned);
    int32_t returnValue__;
    returnValue__ = Discord_GuildChannel_Position(&instance_);
    return returnValue__;
}
void GuildChannel::SetPosition(int32_t Position)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_GuildChannel_SetPosition(&instance_, Position);
}
std::optional<uint64_t> GuildChannel::ParentId() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    uint64_t returnValue__;
    returnIsNonNull__ = Discord_GuildChannel_ParentId(&instance_, &returnValue__);
    if (!returnIsNonNull__) {
        return std::nullopt;
    }
    return returnValue__;
}
void GuildChannel::SetParentId(std::optional<uint64_t> ParentId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_GuildChannel_SetParentId(&instance_, (ParentId.has_value() ? &*ParentId : nullptr));
}
bool GuildChannel::IsLinkable() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_GuildChannel_IsLinkable(&instance_);
    return returnValue__;
}
void GuildChannel::SetIsLinkable(bool IsLinkable)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_GuildChannel_SetIsLinkable(&instance_, IsLinkable);
}
bool GuildChannel::IsViewableAndWriteableByAllMembers() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_GuildChannel_IsViewableAndWriteableByAllMembers(&instance_);
    return returnValue__;
}
void GuildChannel::SetIsViewableAndWriteableByAllMembers(bool IsViewableAndWriteableByAllMembers)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_GuildChannel_SetIsViewableAndWriteableByAllMembers(&instance_,
                                                               IsViewableAndWriteableByAllMembers);
}
std::optional<discordpp::LinkedLobby> GuildChannel::LinkedLobby() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_LinkedLobby returnValueNative__;
    returnIsNonNull__ = Discord_GuildChannel_LinkedLobby(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::LinkedLobby returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
void GuildChannel::SetLinkedLobby(std::optional<discordpp::LinkedLobby> LinkedLobby)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_GuildChannel_SetLinkedLobby(
      &instance_, (LinkedLobby.has_value() ? LinkedLobby->instance() : nullptr));
}
const LinkedLobby LinkedLobby::nullobj{{}, DiscordObjectState::Invalid};
LinkedLobby::~LinkedLobby()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
LinkedLobby::LinkedLobby(LinkedLobby&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
LinkedLobby& LinkedLobby::operator=(LinkedLobby&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
LinkedLobby::LinkedLobby(const LinkedLobby& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_LinkedLobby_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
LinkedLobby& LinkedLobby::operator=(const LinkedLobby& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_LinkedLobby_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
LinkedLobby::LinkedLobby(Discord_LinkedLobby instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
LinkedLobby::LinkedLobby()
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_LinkedLobby_Init(&instance_);
    state_ = DiscordObjectState::Owned;
}
void LinkedLobby::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_LinkedLobby_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
uint64_t LinkedLobby::ApplicationId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_LinkedLobby_ApplicationId(&instance_);
    return returnValue__;
}
void LinkedLobby::SetApplicationId(uint64_t ApplicationId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_LinkedLobby_SetApplicationId(&instance_, ApplicationId);
}
uint64_t LinkedLobby::LobbyId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_LinkedLobby_LobbyId(&instance_);
    return returnValue__;
}
void LinkedLobby::SetLobbyId(uint64_t LobbyId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_LinkedLobby_SetLobbyId(&instance_, LobbyId);
}
const LinkedChannel LinkedChannel::nullobj{{}, DiscordObjectState::Invalid};
LinkedChannel::~LinkedChannel()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
LinkedChannel::LinkedChannel(LinkedChannel&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
LinkedChannel& LinkedChannel::operator=(LinkedChannel&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
LinkedChannel::LinkedChannel(const LinkedChannel& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_LinkedChannel_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
LinkedChannel& LinkedChannel::operator=(const LinkedChannel& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_LinkedChannel_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
LinkedChannel::LinkedChannel(Discord_LinkedChannel instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void LinkedChannel::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_LinkedChannel_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
uint64_t LinkedChannel::Id() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_LinkedChannel_Id(&instance_);
    return returnValue__;
}
void LinkedChannel::SetId(uint64_t Id)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_LinkedChannel_SetId(&instance_, Id);
}
std::string LinkedChannel::Name() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_LinkedChannel_Name(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void LinkedChannel::SetName(std::string Name)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Name__str{(uint8_t*)(Name.data()), Name.size()};
    Discord_LinkedChannel_SetName(&instance_, Name__str);
}
uint64_t LinkedChannel::GuildId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_LinkedChannel_GuildId(&instance_);
    return returnValue__;
}
void LinkedChannel::SetGuildId(uint64_t GuildId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_LinkedChannel_SetGuildId(&instance_, GuildId);
}
const RelationshipHandle RelationshipHandle::nullobj{{}, DiscordObjectState::Invalid};
RelationshipHandle::~RelationshipHandle()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
RelationshipHandle::RelationshipHandle(RelationshipHandle&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
RelationshipHandle& RelationshipHandle::operator=(RelationshipHandle&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
RelationshipHandle::RelationshipHandle(const RelationshipHandle& other)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (other.state_ == DiscordObjectState::Owned) {
        Discord_RelationshipHandle_Clone(&instance_, other.instance());

        state_ = DiscordObjectState::Owned;
    }
}
RelationshipHandle& RelationshipHandle::operator=(const RelationshipHandle& other)
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (other.state_ == DiscordObjectState::Owned) {
            Discord_RelationshipHandle_Clone(&instance_, other.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
RelationshipHandle::RelationshipHandle(Discord_RelationshipHandle instance,
                                       DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void RelationshipHandle::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_RelationshipHandle_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
discordpp::RelationshipType RelationshipHandle::DiscordRelationshipType() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_RelationshipType returnValue__;
    returnValue__ = Discord_RelationshipHandle_DiscordRelationshipType(&instance_);
    return static_cast<discordpp::RelationshipType>(returnValue__);
}
discordpp::RelationshipType RelationshipHandle::GameRelationshipType() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_RelationshipType returnValue__;
    returnValue__ = Discord_RelationshipHandle_GameRelationshipType(&instance_);
    return static_cast<discordpp::RelationshipType>(returnValue__);
}
uint64_t RelationshipHandle::Id() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_RelationshipHandle_Id(&instance_);
    return returnValue__;
}
bool RelationshipHandle::IsSpamRequest() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_RelationshipHandle_IsSpamRequest(&instance_);
    return returnValue__;
}
std::optional<discordpp::UserHandle> RelationshipHandle::User() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_UserHandle returnValueNative__;
    returnIsNonNull__ = Discord_RelationshipHandle_User(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::UserHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
const UserApplicationProfileHandle UserApplicationProfileHandle::nullobj{
  {},
  DiscordObjectState::Invalid};
UserApplicationProfileHandle::~UserApplicationProfileHandle()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
UserApplicationProfileHandle::UserApplicationProfileHandle(
  UserApplicationProfileHandle&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
UserApplicationProfileHandle& UserApplicationProfileHandle::operator=(
  UserApplicationProfileHandle&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
UserApplicationProfileHandle::UserApplicationProfileHandle(
  const UserApplicationProfileHandle& other)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (other.state_ == DiscordObjectState::Owned) {
        Discord_UserApplicationProfileHandle_Clone(&instance_, other.instance());

        state_ = DiscordObjectState::Owned;
    }
}
UserApplicationProfileHandle& UserApplicationProfileHandle::operator=(
  const UserApplicationProfileHandle& other)
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (other.state_ == DiscordObjectState::Owned) {
            Discord_UserApplicationProfileHandle_Clone(&instance_, other.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
UserApplicationProfileHandle::UserApplicationProfileHandle(
  Discord_UserApplicationProfileHandle instance,
  DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void UserApplicationProfileHandle::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_UserApplicationProfileHandle_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
std::string UserApplicationProfileHandle::AvatarHash() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_UserApplicationProfileHandle_AvatarHash(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::string UserApplicationProfileHandle::Metadata() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_UserApplicationProfileHandle_Metadata(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::optional<std::string> UserApplicationProfileHandle::ProviderId() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ =
      Discord_UserApplicationProfileHandle_ProviderId(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::string UserApplicationProfileHandle::ProviderIssuedUserId() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_UserApplicationProfileHandle_ProviderIssuedUserId(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
discordpp::ExternalIdentityProviderType UserApplicationProfileHandle::ProviderType() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ExternalIdentityProviderType returnValue__;
    returnValue__ = Discord_UserApplicationProfileHandle_ProviderType(&instance_);
    return static_cast<discordpp::ExternalIdentityProviderType>(returnValue__);
}
std::string UserApplicationProfileHandle::Username() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_UserApplicationProfileHandle_Username(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
const UserHandle UserHandle::nullobj{{}, DiscordObjectState::Invalid};
UserHandle::~UserHandle()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
UserHandle::UserHandle(UserHandle&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
UserHandle& UserHandle::operator=(UserHandle&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
UserHandle::UserHandle(const UserHandle& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_UserHandle_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
UserHandle& UserHandle::operator=(const UserHandle& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_UserHandle_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
UserHandle::UserHandle(Discord_UserHandle instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void UserHandle::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_UserHandle_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
std::optional<std::string> UserHandle::Avatar() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_UserHandle_Avatar(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::string UserHandle::AvatarTypeToString(discordpp::UserHandle::AvatarType type)
{
    Discord_String returnValueNative__;
    Discord_UserHandle_AvatarTypeToString(static_cast<Discord_UserHandle_AvatarType>(type),
                                          &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::string UserHandle::AvatarUrl(discordpp::UserHandle::AvatarType animatedType,
                                  discordpp::UserHandle::AvatarType staticType) const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_UserHandle_AvatarUrl(&instance_,
                                 static_cast<Discord_UserHandle_AvatarType>(animatedType),
                                 static_cast<Discord_UserHandle_AvatarType>(staticType),
                                 &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::string UserHandle::DisplayName() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_UserHandle_DisplayName(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::optional<discordpp::Activity> UserHandle::GameActivity() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_Activity returnValueNative__;
    returnIsNonNull__ = Discord_UserHandle_GameActivity(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::Activity returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
std::optional<std::string> UserHandle::GlobalName() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_UserHandle_GlobalName(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
uint64_t UserHandle::Id() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_UserHandle_Id(&instance_);
    return returnValue__;
}
bool UserHandle::IsProvisional() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_UserHandle_IsProvisional(&instance_);
    return returnValue__;
}
discordpp::RelationshipHandle UserHandle::Relationship() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_RelationshipHandle returnValueNative__{};
    Discord_UserHandle_Relationship(&instance_, &returnValueNative__);
    discordpp::RelationshipHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
discordpp::StatusType UserHandle::Status() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_StatusType returnValue__;
    returnValue__ = Discord_UserHandle_Status(&instance_);
    return static_cast<discordpp::StatusType>(returnValue__);
}
std::vector<discordpp::UserApplicationProfileHandle> UserHandle::UserApplicationProfiles() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_UserApplicationProfileHandleSpan returnValueNative__;
    Discord_UserHandle_UserApplicationProfiles(&instance_, &returnValueNative__);
    std::vector<discordpp::UserApplicationProfileHandle> returnValue__;
    returnValue__.reserve(returnValueNative__.size);
    for (size_t i__ = 0; i__ < returnValueNative__.size; ++i__) {
        returnValue__.emplace_back(returnValueNative__.ptr[i__], DiscordObjectState::Owned);
    }
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::string UserHandle::Username() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_UserHandle_Username(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
const LobbyMemberHandle LobbyMemberHandle::nullobj{{}, DiscordObjectState::Invalid};
LobbyMemberHandle::~LobbyMemberHandle()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
LobbyMemberHandle::LobbyMemberHandle(LobbyMemberHandle&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
LobbyMemberHandle& LobbyMemberHandle::operator=(LobbyMemberHandle&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
LobbyMemberHandle::LobbyMemberHandle(const LobbyMemberHandle& other)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (other.state_ == DiscordObjectState::Owned) {
        Discord_LobbyMemberHandle_Clone(&instance_, other.instance());

        state_ = DiscordObjectState::Owned;
    }
}
LobbyMemberHandle& LobbyMemberHandle::operator=(const LobbyMemberHandle& other)
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (other.state_ == DiscordObjectState::Owned) {
            Discord_LobbyMemberHandle_Clone(&instance_, other.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
LobbyMemberHandle::LobbyMemberHandle(Discord_LobbyMemberHandle instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void LobbyMemberHandle::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_LobbyMemberHandle_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
bool LobbyMemberHandle::CanLinkLobby() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_LobbyMemberHandle_CanLinkLobby(&instance_);
    return returnValue__;
}
bool LobbyMemberHandle::Connected() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_LobbyMemberHandle_Connected(&instance_);
    return returnValue__;
}
uint64_t LobbyMemberHandle::Id() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_LobbyMemberHandle_Id(&instance_);
    return returnValue__;
}
std::unordered_map<std::string, std::string> LobbyMemberHandle::Metadata() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Properties returnValueNative__;
    Discord_LobbyMemberHandle_Metadata(&instance_, &returnValueNative__);
    std::unordered_map<std::string, std::string> returnValue__ =
      ConvertReturnedProperties(returnValueNative__);
    Discord_FreeProperties(returnValueNative__);
    return returnValue__;
}
std::optional<discordpp::UserHandle> LobbyMemberHandle::User() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_UserHandle returnValueNative__;
    returnIsNonNull__ = Discord_LobbyMemberHandle_User(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::UserHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
const LobbyHandle LobbyHandle::nullobj{{}, DiscordObjectState::Invalid};
LobbyHandle::~LobbyHandle()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
LobbyHandle::LobbyHandle(LobbyHandle&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
LobbyHandle& LobbyHandle::operator=(LobbyHandle&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
LobbyHandle::LobbyHandle(const LobbyHandle& other)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (other.state_ == DiscordObjectState::Owned) {
        Discord_LobbyHandle_Clone(&instance_, other.instance());

        state_ = DiscordObjectState::Owned;
    }
}
LobbyHandle& LobbyHandle::operator=(const LobbyHandle& other)
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (other.state_ == DiscordObjectState::Owned) {
            Discord_LobbyHandle_Clone(&instance_, other.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
LobbyHandle::LobbyHandle(Discord_LobbyHandle instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void LobbyHandle::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_LobbyHandle_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
std::optional<discordpp::CallInfoHandle> LobbyHandle::GetCallInfoHandle() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_CallInfoHandle returnValueNative__;
    returnIsNonNull__ = Discord_LobbyHandle_GetCallInfoHandle(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::CallInfoHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
std::optional<discordpp::LobbyMemberHandle> LobbyHandle::GetLobbyMemberHandle(
  uint64_t memberId) const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_LobbyMemberHandle returnValueNative__;
    returnIsNonNull__ =
      Discord_LobbyHandle_GetLobbyMemberHandle(&instance_, memberId, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::LobbyMemberHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
uint64_t LobbyHandle::Id() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_LobbyHandle_Id(&instance_);
    return returnValue__;
}
std::optional<discordpp::LinkedChannel> LobbyHandle::LinkedChannel() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_LinkedChannel returnValueNative__;
    returnIsNonNull__ = Discord_LobbyHandle_LinkedChannel(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::LinkedChannel returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
std::vector<uint64_t> LobbyHandle::LobbyMemberIds() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_UInt64Span returnValueNative__;
    Discord_LobbyHandle_LobbyMemberIds(&instance_, &returnValueNative__);
    std::vector<uint64_t> returnValue__(returnValueNative__.ptr,
                                        returnValueNative__.ptr + returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::vector<discordpp::LobbyMemberHandle> LobbyHandle::LobbyMembers() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_LobbyMemberHandleSpan returnValueNative__;
    Discord_LobbyHandle_LobbyMembers(&instance_, &returnValueNative__);
    std::vector<discordpp::LobbyMemberHandle> returnValue__;
    returnValue__.reserve(returnValueNative__.size);
    for (size_t i__ = 0; i__ < returnValueNative__.size; ++i__) {
        returnValue__.emplace_back(returnValueNative__.ptr[i__], DiscordObjectState::Owned);
    }
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::unordered_map<std::string, std::string> LobbyHandle::Metadata() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Properties returnValueNative__;
    Discord_LobbyHandle_Metadata(&instance_, &returnValueNative__);
    std::unordered_map<std::string, std::string> returnValue__ =
      ConvertReturnedProperties(returnValueNative__);
    Discord_FreeProperties(returnValueNative__);
    return returnValue__;
}
const AdditionalContent AdditionalContent::nullobj{{}, DiscordObjectState::Invalid};
AdditionalContent::~AdditionalContent()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
AdditionalContent::AdditionalContent(AdditionalContent&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
AdditionalContent& AdditionalContent::operator=(AdditionalContent&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
AdditionalContent::AdditionalContent(const AdditionalContent& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_AdditionalContent_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
AdditionalContent& AdditionalContent::operator=(const AdditionalContent& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_AdditionalContent_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
AdditionalContent::AdditionalContent(Discord_AdditionalContent instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
AdditionalContent::AdditionalContent()
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_AdditionalContent_Init(&instance_);
    state_ = DiscordObjectState::Owned;
}
void AdditionalContent::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_AdditionalContent_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
bool AdditionalContent::Equals(discordpp::AdditionalContent rhs) const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_AdditionalContent_Equals(&instance_, rhs.instance());
    return returnValue__;
}
std::string AdditionalContent::TypeToString(discordpp::AdditionalContentType type)
{
    Discord_String returnValueNative__;
    Discord_AdditionalContent_TypeToString(static_cast<Discord_AdditionalContentType>(type),
                                           &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
discordpp::AdditionalContentType AdditionalContent::Type() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_AdditionalContentType returnValue__;
    returnValue__ = Discord_AdditionalContent_Type(&instance_);
    return static_cast<discordpp::AdditionalContentType>(returnValue__);
}
void AdditionalContent::SetType(discordpp::AdditionalContentType Type)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_AdditionalContent_SetType(&instance_, static_cast<Discord_AdditionalContentType>(Type));
}
std::optional<std::string> AdditionalContent::Title() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_AdditionalContent_Title(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void AdditionalContent::SetTitle(std::optional<std::string> Title)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Title__str{};
    if (Title.has_value()) {
        Title__str.ptr = reinterpret_cast<uint8_t*>(Title->data());
        Title__str.size = Title->size();
    }
    Discord_AdditionalContent_SetTitle(&instance_, (Title.has_value() ? &Title__str : nullptr));
}
uint8_t AdditionalContent::Count() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint8_t returnValue__;
    returnValue__ = Discord_AdditionalContent_Count(&instance_);
    return returnValue__;
}
void AdditionalContent::SetCount(uint8_t Count)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_AdditionalContent_SetCount(&instance_, Count);
}
const MessageHandle MessageHandle::nullobj{{}, DiscordObjectState::Invalid};
MessageHandle::~MessageHandle()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
MessageHandle::MessageHandle(MessageHandle&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
MessageHandle& MessageHandle::operator=(MessageHandle&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
MessageHandle::MessageHandle(const MessageHandle& other)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (other.state_ == DiscordObjectState::Owned) {
        Discord_MessageHandle_Clone(&instance_, other.instance());

        state_ = DiscordObjectState::Owned;
    }
}
MessageHandle& MessageHandle::operator=(const MessageHandle& other)
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (other.state_ == DiscordObjectState::Owned) {
            Discord_MessageHandle_Clone(&instance_, other.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
MessageHandle::MessageHandle(Discord_MessageHandle instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void MessageHandle::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_MessageHandle_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
std::optional<discordpp::AdditionalContent> MessageHandle::AdditionalContent() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_AdditionalContent returnValueNative__;
    returnIsNonNull__ = Discord_MessageHandle_AdditionalContent(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::AdditionalContent returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
std::optional<std::string> MessageHandle::AdditionalName() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_String returnValueNative__;
    returnIsNonNull__ = Discord_MessageHandle_AdditionalName(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::optional<uint64_t> MessageHandle::ApplicationId() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    uint64_t returnValue__;
    returnIsNonNull__ = Discord_MessageHandle_ApplicationId(&instance_, &returnValue__);
    if (!returnIsNonNull__) {
        return std::nullopt;
    }
    return returnValue__;
}
std::optional<discordpp::UserHandle> MessageHandle::Author() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_UserHandle returnValueNative__;
    returnIsNonNull__ = Discord_MessageHandle_Author(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::UserHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
uint64_t MessageHandle::AuthorId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_MessageHandle_AuthorId(&instance_);
    return returnValue__;
}
std::optional<discordpp::ChannelHandle> MessageHandle::Channel() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_ChannelHandle returnValueNative__;
    returnIsNonNull__ = Discord_MessageHandle_Channel(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::ChannelHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
uint64_t MessageHandle::ChannelId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_MessageHandle_ChannelId(&instance_);
    return returnValue__;
}
std::string MessageHandle::Content() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_MessageHandle_Content(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::optional<discordpp::DisclosureTypes> MessageHandle::DisclosureType() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_DisclosureTypes returnValueNative__;
    returnIsNonNull__ = Discord_MessageHandle_DisclosureType(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    auto returnValue__ = static_cast<discordpp::DisclosureTypes>(returnValueNative__);
    return returnValue__;
}
uint64_t MessageHandle::EditedTimestamp() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_MessageHandle_EditedTimestamp(&instance_);
    return returnValue__;
}
uint64_t MessageHandle::Id() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_MessageHandle_Id(&instance_);
    return returnValue__;
}
std::optional<discordpp::LobbyHandle> MessageHandle::Lobby() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_LobbyHandle returnValueNative__;
    returnIsNonNull__ = Discord_MessageHandle_Lobby(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::LobbyHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
std::unordered_map<std::string, std::string> MessageHandle::Metadata() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Properties returnValueNative__;
    Discord_MessageHandle_Metadata(&instance_, &returnValueNative__);
    std::unordered_map<std::string, std::string> returnValue__ =
      ConvertReturnedProperties(returnValueNative__);
    Discord_FreeProperties(returnValueNative__);
    return returnValue__;
}
std::unordered_map<std::string, std::string> MessageHandle::ModerationMetadata() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Properties returnValueNative__;
    Discord_MessageHandle_ModerationMetadata(&instance_, &returnValueNative__);
    std::unordered_map<std::string, std::string> returnValue__ =
      ConvertReturnedProperties(returnValueNative__);
    Discord_FreeProperties(returnValueNative__);
    return returnValue__;
}
std::string MessageHandle::RawContent() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_MessageHandle_RawContent(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::optional<discordpp::UserHandle> MessageHandle::Recipient() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_UserHandle returnValueNative__;
    returnIsNonNull__ = Discord_MessageHandle_Recipient(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::UserHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
uint64_t MessageHandle::RecipientId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_MessageHandle_RecipientId(&instance_);
    return returnValue__;
}
bool MessageHandle::SentFromGame() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_MessageHandle_SentFromGame(&instance_);
    return returnValue__;
}
uint64_t MessageHandle::SentTimestamp() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_MessageHandle_SentTimestamp(&instance_);
    return returnValue__;
}
const AudioDevice AudioDevice::nullobj{{}, DiscordObjectState::Invalid};
AudioDevice::~AudioDevice()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
AudioDevice::AudioDevice(AudioDevice&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
AudioDevice& AudioDevice::operator=(AudioDevice&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
AudioDevice::AudioDevice(const AudioDevice& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_AudioDevice_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
AudioDevice& AudioDevice::operator=(const AudioDevice& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_AudioDevice_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
AudioDevice::AudioDevice(Discord_AudioDevice instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void AudioDevice::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_AudioDevice_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
bool AudioDevice::Equals(discordpp::AudioDevice rhs)
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_AudioDevice_Equals(&instance_, rhs.instance());
    return returnValue__;
}
std::string AudioDevice::Id() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_AudioDevice_Id(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void AudioDevice::SetId(std::string Id)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Id__str{(uint8_t*)(Id.data()), Id.size()};
    Discord_AudioDevice_SetId(&instance_, Id__str);
}
std::string AudioDevice::Name() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_AudioDevice_Name(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void AudioDevice::SetName(std::string Name)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String Name__str{(uint8_t*)(Name.data()), Name.size()};
    Discord_AudioDevice_SetName(&instance_, Name__str);
}
bool AudioDevice::IsDefault() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_AudioDevice_IsDefault(&instance_);
    return returnValue__;
}
void AudioDevice::SetIsDefault(bool IsDefault)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_AudioDevice_SetIsDefault(&instance_, IsDefault);
}
const VoiceSettings VoiceSettings::nullobj{{}, DiscordObjectState::Invalid};
VoiceSettings::~VoiceSettings()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
VoiceSettings::VoiceSettings(VoiceSettings&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
VoiceSettings& VoiceSettings::operator=(VoiceSettings&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
VoiceSettings::VoiceSettings(const VoiceSettings& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_VoiceSettings_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
VoiceSettings& VoiceSettings::operator=(const VoiceSettings& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_VoiceSettings_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
VoiceSettings::VoiceSettings(Discord_VoiceSettings instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void VoiceSettings::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_VoiceSettings_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
bool VoiceSettings::SelfMute() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_VoiceSettings_SelfMute(&instance_);
    return returnValue__;
}
void VoiceSettings::SetSelfMute(bool SelfMute)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_VoiceSettings_SetSelfMute(&instance_, SelfMute);
}
bool VoiceSettings::SelfDeaf() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_VoiceSettings_SelfDeaf(&instance_);
    return returnValue__;
}
void VoiceSettings::SetSelfDeaf(bool SelfDeaf)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_VoiceSettings_SetSelfDeaf(&instance_, SelfDeaf);
}
discordpp::VoiceInputModeType VoiceSettings::InputMode() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_VoiceInputModeType returnValue__;
    returnValue__ = Discord_VoiceSettings_InputMode(&instance_);
    return static_cast<discordpp::VoiceInputModeType>(returnValue__);
}
void VoiceSettings::SetInputMode(discordpp::VoiceInputModeType InputMode)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_VoiceSettings_SetInputMode(&instance_,
                                       static_cast<Discord_VoiceInputModeType>(InputMode));
}
std::string VoiceSettings::PttKey() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_VoiceSettings_PttKey(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void VoiceSettings::SetPttKey(std::string PttKey)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String PttKey__str{(uint8_t*)(PttKey.data()), PttKey.size()};
    Discord_VoiceSettings_SetPttKey(&instance_, PttKey__str);
}
float VoiceSettings::InputVolume() const
{
    assert(state_ == DiscordObjectState::Owned);
    float returnValue__;
    returnValue__ = Discord_VoiceSettings_InputVolume(&instance_);
    return returnValue__;
}
void VoiceSettings::SetInputVolume(float InputVolume)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_VoiceSettings_SetInputVolume(&instance_, InputVolume);
}
float VoiceSettings::OutputVolume() const
{
    assert(state_ == DiscordObjectState::Owned);
    float returnValue__;
    returnValue__ = Discord_VoiceSettings_OutputVolume(&instance_);
    return returnValue__;
}
void VoiceSettings::SetOutputVolume(float OutputVolume)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_VoiceSettings_SetOutputVolume(&instance_, OutputVolume);
}
bool VoiceSettings::AutomaticGainControl() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_VoiceSettings_AutomaticGainControl(&instance_);
    return returnValue__;
}
void VoiceSettings::SetAutomaticGainControl(bool AutomaticGainControl)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_VoiceSettings_SetAutomaticGainControl(&instance_, AutomaticGainControl);
}
bool VoiceSettings::EchoCancellation() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_VoiceSettings_EchoCancellation(&instance_);
    return returnValue__;
}
void VoiceSettings::SetEchoCancellation(bool EchoCancellation)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_VoiceSettings_SetEchoCancellation(&instance_, EchoCancellation);
}
bool VoiceSettings::NoiseSuppression() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_VoiceSettings_NoiseSuppression(&instance_);
    return returnValue__;
}
void VoiceSettings::SetNoiseSuppression(bool NoiseSuppression)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_VoiceSettings_SetNoiseSuppression(&instance_, NoiseSuppression);
}
bool VoiceSettings::NoiseCancellation() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_VoiceSettings_NoiseCancellation(&instance_);
    return returnValue__;
}
void VoiceSettings::SetNoiseCancellation(bool NoiseCancellation)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_VoiceSettings_SetNoiseCancellation(&instance_, NoiseCancellation);
}
const UserMessageSummary UserMessageSummary::nullobj{{}, DiscordObjectState::Invalid};
UserMessageSummary::~UserMessageSummary()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
UserMessageSummary::UserMessageSummary(UserMessageSummary&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
UserMessageSummary& UserMessageSummary::operator=(UserMessageSummary&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
UserMessageSummary::UserMessageSummary(const UserMessageSummary& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_UserMessageSummary_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
UserMessageSummary& UserMessageSummary::operator=(const UserMessageSummary& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_UserMessageSummary_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
UserMessageSummary::UserMessageSummary(Discord_UserMessageSummary instance,
                                       DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void UserMessageSummary::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_UserMessageSummary_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
uint64_t UserMessageSummary::LastMessageId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_UserMessageSummary_LastMessageId(&instance_);
    return returnValue__;
}
uint64_t UserMessageSummary::UserId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_UserMessageSummary_UserId(&instance_);
    return returnValue__;
}
const ClientCreateOptions ClientCreateOptions::nullobj{{}, DiscordObjectState::Invalid};
ClientCreateOptions::~ClientCreateOptions()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
ClientCreateOptions::ClientCreateOptions(ClientCreateOptions&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
ClientCreateOptions& ClientCreateOptions::operator=(ClientCreateOptions&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
ClientCreateOptions::ClientCreateOptions(const ClientCreateOptions& arg0)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (arg0.state_ == DiscordObjectState::Owned) {
        Discord_ClientCreateOptions_Clone(&instance_, arg0.instance());

        state_ = DiscordObjectState::Owned;
    }
}
ClientCreateOptions& ClientCreateOptions::operator=(const ClientCreateOptions& arg0)
{
    if (this != &arg0) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (arg0.state_ == DiscordObjectState::Owned) {
            Discord_ClientCreateOptions_Clone(&instance_, arg0.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
ClientCreateOptions::ClientCreateOptions(Discord_ClientCreateOptions instance,
                                         DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
ClientCreateOptions::ClientCreateOptions()
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_ClientCreateOptions_Init(&instance_);
    state_ = DiscordObjectState::Owned;
}
void ClientCreateOptions::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_ClientCreateOptions_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
std::string ClientCreateOptions::WebBase() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_ClientCreateOptions_WebBase(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ClientCreateOptions::SetWebBase(std::string WebBase)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String WebBase__str{(uint8_t*)(WebBase.data()), WebBase.size()};
    Discord_ClientCreateOptions_SetWebBase(&instance_, WebBase__str);
}
std::string ClientCreateOptions::ApiBase() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String returnValueNative__;
    Discord_ClientCreateOptions_ApiBase(&instance_, &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void ClientCreateOptions::SetApiBase(std::string ApiBase)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String ApiBase__str{(uint8_t*)(ApiBase.data()), ApiBase.size()};
    Discord_ClientCreateOptions_SetApiBase(&instance_, ApiBase__str);
}
discordpp::AudioSystem ClientCreateOptions::ExperimentalAudioSystem() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_AudioSystem returnValue__;
    returnValue__ = Discord_ClientCreateOptions_ExperimentalAudioSystem(&instance_);
    return static_cast<discordpp::AudioSystem>(returnValue__);
}
void ClientCreateOptions::SetExperimentalAudioSystem(discordpp::AudioSystem ExperimentalAudioSystem)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ClientCreateOptions_SetExperimentalAudioSystem(
      &instance_, static_cast<Discord_AudioSystem>(ExperimentalAudioSystem));
}
bool ClientCreateOptions::ExperimentalAndroidPreventCommsForBluetooth() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ =
      Discord_ClientCreateOptions_ExperimentalAndroidPreventCommsForBluetooth(&instance_);
    return returnValue__;
}
void ClientCreateOptions::SetExperimentalAndroidPreventCommsForBluetooth(
  bool ExperimentalAndroidPreventCommsForBluetooth)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ClientCreateOptions_SetExperimentalAndroidPreventCommsForBluetooth(
      &instance_, ExperimentalAndroidPreventCommsForBluetooth);
}
std::optional<uint64_t> ClientCreateOptions::CpuAffinityMask() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    uint64_t returnValue__;
    returnIsNonNull__ = Discord_ClientCreateOptions_CpuAffinityMask(&instance_, &returnValue__);
    if (!returnIsNonNull__) {
        return std::nullopt;
    }
    return returnValue__;
}
void ClientCreateOptions::SetCpuAffinityMask(std::optional<uint64_t> CpuAffinityMask)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_ClientCreateOptions_SetCpuAffinityMask(
      &instance_, (CpuAffinityMask.has_value() ? &*CpuAffinityMask : nullptr));
}
const Client Client::nullobj{{}, DiscordObjectState::Invalid};
Client::~Client()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
Client::Client(Client&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
Client& Client::operator=(Client&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
Client::Client(Discord_Client instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
Client::Client()
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_Client_Init(&instance_);
    state_ = DiscordObjectState::Owned;
}
Client::Client(std::string apiBase, std::string webBase)
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_String apiBase__str{(uint8_t*)(apiBase.data()), apiBase.size()};
    Discord_String webBase__str{(uint8_t*)(webBase.data()), webBase.size()};
    Discord_Client_InitWithBases(&instance_, apiBase__str, webBase__str);
    state_ = DiscordObjectState::Owned;
}
Client::Client(discordpp::ClientCreateOptions options)
{
    assert(state_ == DiscordObjectState::Invalid);
    Discord_Client_InitWithOptions(&instance_, options.instance());
    state_ = DiscordObjectState::Owned;
}
void Client::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_Client_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
std::string Client::ErrorToString(discordpp::Client::Error type)
{
    Discord_String returnValueNative__;
    Discord_Client_ErrorToString(static_cast<Discord_Client_Error>(type), &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
uint64_t Client::GetApplicationId()
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_Client_GetApplicationId(&instance_);
    return returnValue__;
}
discordpp::UserHandle Client::GetCurrentUser() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_UserHandle returnValueNative__{};
    Discord_Client_GetCurrentUser(&instance_, &returnValueNative__);
    discordpp::UserHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
std::string Client::GetDefaultAudioDeviceId()
{
    Discord_String returnValueNative__;
    Discord_Client_GetDefaultAudioDeviceId(&returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::string Client::GetDefaultCommunicationScopes()
{
    Discord_String returnValueNative__;
    Discord_Client_GetDefaultCommunicationScopes(&returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::string Client::GetDefaultPresenceScopes()
{
    Discord_String returnValueNative__;
    Discord_Client_GetDefaultPresenceScopes(&returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::string Client::GetVersionHash()
{
    Discord_String returnValueNative__;
    Discord_Client_GetVersionHash(&returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
int32_t Client::GetVersionMajor()
{
    int32_t returnValue__;
    returnValue__ = Discord_Client_GetVersionMajor();
    return returnValue__;
}
int32_t Client::GetVersionMinor()
{
    int32_t returnValue__;
    returnValue__ = Discord_Client_GetVersionMinor();
    return returnValue__;
}
int32_t Client::GetVersionPatch()
{
    int32_t returnValue__;
    returnValue__ = Discord_Client_GetVersionPatch();
    return returnValue__;
}
void Client::SetHttpRequestTimeout(int32_t httpTimeoutInMilliseconds)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetHttpRequestTimeout(&instance_, httpTimeoutInMilliseconds);
}
std::string Client::StatusToString(discordpp::Client::Status type)
{
    Discord_String returnValueNative__;
    Discord_Client_StatusToString(static_cast<Discord_Client_Status>(type), &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::string Client::ThreadToString(discordpp::Client::Thread type)
{
    Discord_String returnValueNative__;
    Discord_Client_ThreadToString(static_cast<Discord_Client_Thread>(type), &returnValueNative__);
    std::string returnValue__(reinterpret_cast<char*>(returnValueNative__.ptr),
                              returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void Client::EndCall(uint64_t channelId, discordpp::Client::EndCallCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_EndCallCallback callback__native = [](void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        userData__typed->delegate();
    };
    Discord_Client_EndCall(
      &instance_, channelId, callback__native, Tcallback__UserData::Free, callback__userData);
}
void Client::EndCalls(discordpp::Client::EndCallsCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_EndCallsCallback callback__native = [](void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        userData__typed->delegate();
    };
    Discord_Client_EndCalls(
      &instance_, callback__native, Tcallback__UserData::Free, callback__userData);
}
discordpp::Call Client::GetCall(uint64_t channelId)
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_Call returnValueNative__{};
    returnIsNonNull__ = Discord_Client_GetCall(&instance_, channelId, &returnValueNative__);
    discordpp::Call returnValue__(
      returnValueNative__,
      returnIsNonNull__ ? DiscordObjectState::Owned : DiscordObjectState::Invalid);
    return returnValue__;
}
std::vector<discordpp::Call> Client::GetCalls()
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_CallSpan returnValueNative__;
    Discord_Client_GetCalls(&instance_, &returnValueNative__);
    std::vector<discordpp::Call> returnValue__;
    returnValue__.reserve(returnValueNative__.size);
    for (size_t i__ = 0; i__ < returnValueNative__.size; ++i__) {
        returnValue__.emplace_back(returnValueNative__.ptr[i__], DiscordObjectState::Owned);
    }
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void Client::GetCurrentInputDevice(discordpp::Client::GetCurrentInputDeviceCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_GetCurrentInputDeviceCallback cb__native = [](auto device, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::AudioDevice device__obj(*device, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(device__obj));
    };
    Discord_Client_GetCurrentInputDevice(&instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::GetCurrentOutputDevice(discordpp::Client::GetCurrentOutputDeviceCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_GetCurrentOutputDeviceCallback cb__native = [](auto device, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::AudioDevice device__obj(*device, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(device__obj));
    };
    Discord_Client_GetCurrentOutputDevice(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::GetInputDevices(discordpp::Client::GetInputDevicesCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_GetInputDevicesCallback cb__native = [](auto devices, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        std::vector<discordpp::AudioDevice> devices__vec;
        devices__vec.reserve(devices.size);
        for (size_t i__ = 0; i__ < devices.size; ++i__) {
            devices__vec.emplace_back(devices.ptr[i__], DiscordObjectState::Owned);
        }
        Discord_Free(devices.ptr);
        userData__typed->delegate(std::move(devices__vec));
    };
    Discord_Client_GetInputDevices(&instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
float Client::GetInputVolume()
{
    assert(state_ == DiscordObjectState::Owned);
    float returnValue__;
    returnValue__ = Discord_Client_GetInputVolume(&instance_);
    return returnValue__;
}
void Client::GetOutputDevices(discordpp::Client::GetOutputDevicesCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_GetOutputDevicesCallback cb__native = [](auto devices, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        std::vector<discordpp::AudioDevice> devices__vec;
        devices__vec.reserve(devices.size);
        for (size_t i__ = 0; i__ < devices.size; ++i__) {
            devices__vec.emplace_back(devices.ptr[i__], DiscordObjectState::Owned);
        }
        Discord_Free(devices.ptr);
        userData__typed->delegate(std::move(devices__vec));
    };
    Discord_Client_GetOutputDevices(&instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
float Client::GetOutputVolume()
{
    assert(state_ == DiscordObjectState::Owned);
    float returnValue__;
    returnValue__ = Discord_Client_GetOutputVolume(&instance_);
    return returnValue__;
}
bool Client::GetSelfDeafAll() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_Client_GetSelfDeafAll(&instance_);
    return returnValue__;
}
bool Client::GetSelfMuteAll() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_Client_GetSelfMuteAll(&instance_);
    return returnValue__;
}
void Client::GetVoiceSettings(discordpp::Client::GetVoiceSettingsCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_GetVoiceSettingsCallback cb__native =
      [](auto result, auto settings, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          discordpp::VoiceSettings settings__obj(*settings, DiscordObjectState::Owned);
          userData__typed->delegate(std::move(result__obj), std::move(settings__obj));
      };
    Discord_Client_GetVoiceSettings(&instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetAecDump(bool on)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetAecDump(&instance_, on);
}
void Client::SetAutomaticGainControl(bool on)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetAutomaticGainControl(&instance_, on);
}
void Client::SetDeviceChangeCallback(discordpp::Client::DeviceChangeCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_DeviceChangeCallback callback__native =
      [](auto inputDevices, auto outputDevices, void* userData__) {
          auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
          std::vector<discordpp::AudioDevice> inputDevices__vec;
          inputDevices__vec.reserve(inputDevices.size);
          for (size_t i__ = 0; i__ < inputDevices.size; ++i__) {
              inputDevices__vec.emplace_back(inputDevices.ptr[i__], DiscordObjectState::Owned);
          }
          Discord_Free(inputDevices.ptr);
          std::vector<discordpp::AudioDevice> outputDevices__vec;
          outputDevices__vec.reserve(outputDevices.size);
          for (size_t i__ = 0; i__ < outputDevices.size; ++i__) {
              outputDevices__vec.emplace_back(outputDevices.ptr[i__], DiscordObjectState::Owned);
          }
          Discord_Free(outputDevices.ptr);
          userData__typed->delegate(std::move(inputDevices__vec), std::move(outputDevices__vec));
      };
    Discord_Client_SetDeviceChangeCallback(
      &instance_, callback__native, Tcallback__UserData::Free, callback__userData);
}
void Client::SetEchoCancellation(bool on)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetEchoCancellation(&instance_, on);
}
void Client::SetEngineManagedAudioSession(bool isEngineManaged)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetEngineManagedAudioSession(&instance_, isEngineManaged);
}
void Client::SetInputDevice(std::string deviceId, discordpp::Client::SetInputDeviceCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String deviceId__str{(uint8_t*)(deviceId.data()), deviceId.size()};
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_SetInputDeviceCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_SetInputDevice(
      &instance_, deviceId__str, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetInputVolume(float inputVolume)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetInputVolume(&instance_, inputVolume);
}
void Client::SetNoAudioInputCallback(discordpp::Client::NoAudioInputCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_NoAudioInputCallback callback__native = [](auto inputDetected,
                                                              void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        userData__typed->delegate(inputDetected);
    };
    Discord_Client_SetNoAudioInputCallback(
      &instance_, callback__native, Tcallback__UserData::Free, callback__userData);
}
void Client::SetNoAudioInputThreshold(float dBFSThreshold)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetNoAudioInputThreshold(&instance_, dBFSThreshold);
}
void Client::SetNoiseCancellation(bool on)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetNoiseCancellation(&instance_, on);
}
void Client::SetNoiseSuppression(bool on)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetNoiseSuppression(&instance_, on);
}
void Client::SetOpusHardwareCoding(bool encode, bool decode)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetOpusHardwareCoding(&instance_, encode, decode);
}
void Client::SetOutputDevice(std::string deviceId, discordpp::Client::SetOutputDeviceCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String deviceId__str{(uint8_t*)(deviceId.data()), deviceId.size()};
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_SetOutputDeviceCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_SetOutputDevice(
      &instance_, deviceId__str, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetOutputVolume(float outputVolume)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetOutputVolume(&instance_, outputVolume);
}
void Client::SetSelfDeafAll(bool deaf)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetSelfDeafAll(&instance_, deaf);
}
void Client::SetSelfMuteAll(bool mute)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetSelfMuteAll(&instance_, mute);
}
bool Client::SetSpeakerMode(bool speakerMode)
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_Client_SetSpeakerMode(&instance_, speakerMode);
    return returnValue__;
}
void Client::SetThreadPriority(discordpp::Client::Thread thread, int32_t priority)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetThreadPriority(
      &instance_, static_cast<Discord_Client_Thread>(thread), priority);
}
void Client::SetVoiceParticipantChangedCallback(
  discordpp::Client::VoiceParticipantChangedCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_VoiceParticipantChangedCallback cb__native =
      [](auto lobbyId, auto memberId, auto added, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          userData__typed->delegate(lobbyId, memberId, added);
      };
    Discord_Client_SetVoiceParticipantChangedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetVoiceSettingsUpdatedCallback(
  discordpp::Client::VoiceSettingsUpdatedCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_VoiceSettingsUpdatedCallback callback__native = [](auto settings,
                                                                      void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::VoiceSettings settings__obj(*settings, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(settings__obj));
    };
    Discord_Client_SetVoiceSettingsUpdatedCallback(
      &instance_, callback__native, Tcallback__UserData::Free, callback__userData);
}
bool Client::ShowAudioRoutePicker()
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_Client_ShowAudioRoutePicker(&instance_);
    return returnValue__;
}
discordpp::Call Client::StartCall(uint64_t channelId)
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_Call returnValueNative__{};
    returnIsNonNull__ = Discord_Client_StartCall(&instance_, channelId, &returnValueNative__);
    discordpp::Call returnValue__(
      returnValueNative__,
      returnIsNonNull__ ? DiscordObjectState::Owned : DiscordObjectState::Invalid);
    return returnValue__;
}
discordpp::Call Client::StartCallWithAudioCallbacks(
  uint64_t lobbyId,
  discordpp::Client::UserAudioReceivedCallback receivedCb,
  discordpp::Client::UserAudioCapturedCallback capturedCb)
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_Call returnValueNative__{};
    using TreceivedCb__UserData = TDelegateUserData<std::remove_reference_t<decltype(receivedCb)>>;
    auto receivedCb__userData = new TreceivedCb__UserData(receivedCb);
    Discord_Client_UserAudioReceivedCallback receivedCb__native = [](auto userId,
                                                                     auto data,
                                                                     auto samplesPerChannel,
                                                                     auto sampleRate,
                                                                     auto channels,
                                                                     auto outShouldMute,
                                                                     void* userData__) {
        auto userData__typed = static_cast<TreceivedCb__UserData*>(userData__);
        userData__typed->delegate(
          userId, data, samplesPerChannel, sampleRate, channels, *outShouldMute);
    };
    using TcapturedCb__UserData = TDelegateUserData<std::remove_reference_t<decltype(capturedCb)>>;
    auto capturedCb__userData = new TcapturedCb__UserData(capturedCb);
    Discord_Client_UserAudioCapturedCallback capturedCb__native =
      [](auto data, auto samplesPerChannel, auto sampleRate, auto channels, void* userData__) {
          auto userData__typed = static_cast<TcapturedCb__UserData*>(userData__);
          userData__typed->delegate(data, samplesPerChannel, sampleRate, channels);
      };
    returnIsNonNull__ = Discord_Client_StartCallWithAudioCallbacks(&instance_,
                                                                   lobbyId,
                                                                   receivedCb__native,
                                                                   TreceivedCb__UserData::Free,
                                                                   receivedCb__userData,
                                                                   capturedCb__native,
                                                                   TcapturedCb__UserData::Free,
                                                                   capturedCb__userData,
                                                                   &returnValueNative__);
    discordpp::Call returnValue__(
      returnValueNative__,
      returnIsNonNull__ ? DiscordObjectState::Owned : DiscordObjectState::Invalid);
    return returnValue__;
}
void Client::AbortAuthorize()
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_AbortAuthorize(&instance_);
}
void Client::AbortGetTokenFromDevice()
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_AbortGetTokenFromDevice(&instance_);
}
void Client::Authorize(discordpp::AuthorizationArgs args,
                       discordpp::Client::AuthorizationCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_AuthorizationCallback callback__native =
      [](auto result, auto code, auto redirectUri, void* userData__) {
          auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          std::string code__str(reinterpret_cast<char*>(code.ptr), code.size);
          std::string redirectUri__str(reinterpret_cast<char*>(redirectUri.ptr), redirectUri.size);
          userData__typed->delegate(
            std::move(result__obj), std::move(code__str), std::move(redirectUri__str));
          Discord_Free(redirectUri.ptr);
          Discord_Free(code.ptr);
      };
    Discord_Client_Authorize(
      &instance_, args.instance(), callback__native, Tcallback__UserData::Free, callback__userData);
}
void Client::CloseAuthorizeDeviceScreen()
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_CloseAuthorizeDeviceScreen(&instance_);
}
discordpp::AuthorizationCodeVerifier Client::CreateAuthorizationCodeVerifier()
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_AuthorizationCodeVerifier returnValueNative__{};
    Discord_Client_CreateAuthorizationCodeVerifier(&instance_, &returnValueNative__);
    discordpp::AuthorizationCodeVerifier returnValue__(returnValueNative__,
                                                       DiscordObjectState::Owned);
    return returnValue__;
}
void Client::ExchangeChildToken(std::string const& parentApplicationToken,
                                uint64_t childApplicationId,
                                discordpp::Client::ExchangeChildTokenCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String parentApplicationToken__str{(uint8_t*)(parentApplicationToken.data()),
                                               parentApplicationToken.size()};
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_ExchangeChildTokenCallback callback__native = [](auto result,
                                                                    auto accessToken,
                                                                    auto tokenType,
                                                                    auto expiresIn,
                                                                    auto scopes,
                                                                    void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        std::string accessToken__str(reinterpret_cast<char*>(accessToken.ptr), accessToken.size);
        std::string scopes__str(reinterpret_cast<char*>(scopes.ptr), scopes.size);
        userData__typed->delegate(std::move(result__obj),
                                  std::move(accessToken__str),
                                  static_cast<discordpp::AuthorizationTokenType>(tokenType),
                                  expiresIn,
                                  std::move(scopes__str));
        Discord_Free(scopes.ptr);
        Discord_Free(accessToken.ptr);
    };
    Discord_Client_ExchangeChildToken(&instance_,
                                      parentApplicationToken__str,
                                      childApplicationId,
                                      callback__native,
                                      Tcallback__UserData::Free,
                                      callback__userData);
}
void Client::FetchCurrentUser(discordpp::AuthorizationTokenType tokenType,
                              std::string const& token,
                              discordpp::Client::FetchCurrentUserCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String token__str{(uint8_t*)(token.data()), token.size()};
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_FetchCurrentUserCallback callback__native =
      [](auto result, auto id, auto name, void* userData__) {
          auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          std::string name__str(reinterpret_cast<char*>(name.ptr), name.size);
          userData__typed->delegate(std::move(result__obj), id, std::move(name__str));
          Discord_Free(name.ptr);
      };
    Discord_Client_FetchCurrentUser(&instance_,
                                    static_cast<Discord_AuthorizationTokenType>(tokenType),
                                    token__str,
                                    callback__native,
                                    Tcallback__UserData::Free,
                                    callback__userData);
}
void Client::GetProvisionalToken(uint64_t applicationId,
                                 discordpp::AuthenticationExternalAuthType externalAuthType,
                                 std::string const& externalAuthToken,
                                 discordpp::Client::TokenExchangeCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String externalAuthToken__str{(uint8_t*)(externalAuthToken.data()),
                                          externalAuthToken.size()};
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_TokenExchangeCallback callback__native = [](auto result,
                                                               auto accessToken,
                                                               auto refreshToken,
                                                               auto tokenType,
                                                               auto expiresIn,
                                                               auto scopes,
                                                               void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        std::string accessToken__str(reinterpret_cast<char*>(accessToken.ptr), accessToken.size);
        std::string refreshToken__str(reinterpret_cast<char*>(refreshToken.ptr), refreshToken.size);
        std::string scopes__str(reinterpret_cast<char*>(scopes.ptr), scopes.size);
        userData__typed->delegate(std::move(result__obj),
                                  std::move(accessToken__str),
                                  std::move(refreshToken__str),
                                  static_cast<discordpp::AuthorizationTokenType>(tokenType),
                                  expiresIn,
                                  std::move(scopes__str));
        Discord_Free(scopes.ptr);
        Discord_Free(refreshToken.ptr);
        Discord_Free(accessToken.ptr);
    };
    Discord_Client_GetProvisionalToken(
      &instance_,
      applicationId,
      static_cast<Discord_AuthenticationExternalAuthType>(externalAuthType),
      externalAuthToken__str,
      callback__native,
      Tcallback__UserData::Free,
      callback__userData);
}
void Client::GetToken(uint64_t applicationId,
                      std::string const& code,
                      std::string const& codeVerifier,
                      std::string const& redirectUri,
                      discordpp::Client::TokenExchangeCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String code__str{(uint8_t*)(code.data()), code.size()};
    Discord_String codeVerifier__str{(uint8_t*)(codeVerifier.data()), codeVerifier.size()};
    Discord_String redirectUri__str{(uint8_t*)(redirectUri.data()), redirectUri.size()};
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_TokenExchangeCallback callback__native = [](auto result,
                                                               auto accessToken,
                                                               auto refreshToken,
                                                               auto tokenType,
                                                               auto expiresIn,
                                                               auto scopes,
                                                               void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        std::string accessToken__str(reinterpret_cast<char*>(accessToken.ptr), accessToken.size);
        std::string refreshToken__str(reinterpret_cast<char*>(refreshToken.ptr), refreshToken.size);
        std::string scopes__str(reinterpret_cast<char*>(scopes.ptr), scopes.size);
        userData__typed->delegate(std::move(result__obj),
                                  std::move(accessToken__str),
                                  std::move(refreshToken__str),
                                  static_cast<discordpp::AuthorizationTokenType>(tokenType),
                                  expiresIn,
                                  std::move(scopes__str));
        Discord_Free(scopes.ptr);
        Discord_Free(refreshToken.ptr);
        Discord_Free(accessToken.ptr);
    };
    Discord_Client_GetToken(&instance_,
                            applicationId,
                            code__str,
                            codeVerifier__str,
                            redirectUri__str,
                            callback__native,
                            Tcallback__UserData::Free,
                            callback__userData);
}
void Client::GetTokenFromDevice(discordpp::DeviceAuthorizationArgs args,
                                discordpp::Client::TokenExchangeCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_TokenExchangeCallback callback__native = [](auto result,
                                                               auto accessToken,
                                                               auto refreshToken,
                                                               auto tokenType,
                                                               auto expiresIn,
                                                               auto scopes,
                                                               void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        std::string accessToken__str(reinterpret_cast<char*>(accessToken.ptr), accessToken.size);
        std::string refreshToken__str(reinterpret_cast<char*>(refreshToken.ptr), refreshToken.size);
        std::string scopes__str(reinterpret_cast<char*>(scopes.ptr), scopes.size);
        userData__typed->delegate(std::move(result__obj),
                                  std::move(accessToken__str),
                                  std::move(refreshToken__str),
                                  static_cast<discordpp::AuthorizationTokenType>(tokenType),
                                  expiresIn,
                                  std::move(scopes__str));
        Discord_Free(scopes.ptr);
        Discord_Free(refreshToken.ptr);
        Discord_Free(accessToken.ptr);
    };
    Discord_Client_GetTokenFromDevice(
      &instance_, args.instance(), callback__native, Tcallback__UserData::Free, callback__userData);
}
void Client::GetTokenFromDeviceProvisionalMerge(
  discordpp::DeviceAuthorizationArgs args,
  discordpp::AuthenticationExternalAuthType externalAuthType,
  std::string const& externalAuthToken,
  discordpp::Client::TokenExchangeCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String externalAuthToken__str{(uint8_t*)(externalAuthToken.data()),
                                          externalAuthToken.size()};
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_TokenExchangeCallback callback__native = [](auto result,
                                                               auto accessToken,
                                                               auto refreshToken,
                                                               auto tokenType,
                                                               auto expiresIn,
                                                               auto scopes,
                                                               void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        std::string accessToken__str(reinterpret_cast<char*>(accessToken.ptr), accessToken.size);
        std::string refreshToken__str(reinterpret_cast<char*>(refreshToken.ptr), refreshToken.size);
        std::string scopes__str(reinterpret_cast<char*>(scopes.ptr), scopes.size);
        userData__typed->delegate(std::move(result__obj),
                                  std::move(accessToken__str),
                                  std::move(refreshToken__str),
                                  static_cast<discordpp::AuthorizationTokenType>(tokenType),
                                  expiresIn,
                                  std::move(scopes__str));
        Discord_Free(scopes.ptr);
        Discord_Free(refreshToken.ptr);
        Discord_Free(accessToken.ptr);
    };
    Discord_Client_GetTokenFromDeviceProvisionalMerge(
      &instance_,
      args.instance(),
      static_cast<Discord_AuthenticationExternalAuthType>(externalAuthType),
      externalAuthToken__str,
      callback__native,
      Tcallback__UserData::Free,
      callback__userData);
}
void Client::GetTokenFromProvisionalMerge(
  uint64_t applicationId,
  std::string const& code,
  std::string const& codeVerifier,
  std::string const& redirectUri,
  discordpp::AuthenticationExternalAuthType externalAuthType,
  std::string const& externalAuthToken,
  discordpp::Client::TokenExchangeCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String code__str{(uint8_t*)(code.data()), code.size()};
    Discord_String codeVerifier__str{(uint8_t*)(codeVerifier.data()), codeVerifier.size()};
    Discord_String redirectUri__str{(uint8_t*)(redirectUri.data()), redirectUri.size()};
    Discord_String externalAuthToken__str{(uint8_t*)(externalAuthToken.data()),
                                          externalAuthToken.size()};
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_TokenExchangeCallback callback__native = [](auto result,
                                                               auto accessToken,
                                                               auto refreshToken,
                                                               auto tokenType,
                                                               auto expiresIn,
                                                               auto scopes,
                                                               void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        std::string accessToken__str(reinterpret_cast<char*>(accessToken.ptr), accessToken.size);
        std::string refreshToken__str(reinterpret_cast<char*>(refreshToken.ptr), refreshToken.size);
        std::string scopes__str(reinterpret_cast<char*>(scopes.ptr), scopes.size);
        userData__typed->delegate(std::move(result__obj),
                                  std::move(accessToken__str),
                                  std::move(refreshToken__str),
                                  static_cast<discordpp::AuthorizationTokenType>(tokenType),
                                  expiresIn,
                                  std::move(scopes__str));
        Discord_Free(scopes.ptr);
        Discord_Free(refreshToken.ptr);
        Discord_Free(accessToken.ptr);
    };
    Discord_Client_GetTokenFromProvisionalMerge(
      &instance_,
      applicationId,
      code__str,
      codeVerifier__str,
      redirectUri__str,
      static_cast<Discord_AuthenticationExternalAuthType>(externalAuthType),
      externalAuthToken__str,
      callback__native,
      Tcallback__UserData::Free,
      callback__userData);
}
bool Client::IsAuthenticated()
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_Client_IsAuthenticated(&instance_);
    return returnValue__;
}
void Client::OpenAuthorizeDeviceScreen(uint64_t clientId, std::string const& userCode)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String userCode__str{(uint8_t*)(userCode.data()), userCode.size()};
    Discord_Client_OpenAuthorizeDeviceScreen(&instance_, clientId, userCode__str);
}
void Client::ProvisionalUserMergeCompleted(bool success)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_ProvisionalUserMergeCompleted(&instance_, success);
}
void Client::RefreshToken(uint64_t applicationId,
                          std::string const& refreshToken,
                          discordpp::Client::TokenExchangeCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String refreshToken__str{(uint8_t*)(refreshToken.data()), refreshToken.size()};
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_TokenExchangeCallback callback__native = [](auto result,
                                                               auto accessToken,
                                                               auto refreshToken,
                                                               auto tokenType,
                                                               auto expiresIn,
                                                               auto scopes,
                                                               void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        std::string accessToken__str(reinterpret_cast<char*>(accessToken.ptr), accessToken.size);
        std::string refreshToken__str(reinterpret_cast<char*>(refreshToken.ptr), refreshToken.size);
        std::string scopes__str(reinterpret_cast<char*>(scopes.ptr), scopes.size);
        userData__typed->delegate(std::move(result__obj),
                                  std::move(accessToken__str),
                                  std::move(refreshToken__str),
                                  static_cast<discordpp::AuthorizationTokenType>(tokenType),
                                  expiresIn,
                                  std::move(scopes__str));
        Discord_Free(scopes.ptr);
        Discord_Free(refreshToken.ptr);
        Discord_Free(accessToken.ptr);
    };
    Discord_Client_RefreshToken(&instance_,
                                applicationId,
                                refreshToken__str,
                                callback__native,
                                Tcallback__UserData::Free,
                                callback__userData);
}
void Client::RegisterAuthorizeRequestCallback(discordpp::Client::AuthorizeRequestCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_AuthorizeRequestCallback callback__native = [](void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        userData__typed->delegate();
    };
    Discord_Client_RegisterAuthorizeRequestCallback(
      &instance_, callback__native, Tcallback__UserData::Free, callback__userData);
}
void Client::RemoveAuthorizeRequestCallback()
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_RemoveAuthorizeRequestCallback(&instance_);
}
void Client::RevokeToken(uint64_t applicationId,
                         std::string const& token,
                         discordpp::Client::RevokeTokenCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String token__str{(uint8_t*)(token.data()), token.size()};
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_RevokeTokenCallback callback__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_RevokeToken(&instance_,
                               applicationId,
                               token__str,
                               callback__native,
                               Tcallback__UserData::Free,
                               callback__userData);
}
void Client::SetAuthorizeDeviceScreenClosedCallback(
  discordpp::Client::AuthorizeDeviceScreenClosedCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_AuthorizeDeviceScreenClosedCallback cb__native = [](void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        userData__typed->delegate();
    };
    Discord_Client_SetAuthorizeDeviceScreenClosedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetGameWindowPid(int32_t pid)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetGameWindowPid(&instance_, pid);
}
void Client::SetTokenExpirationCallback(discordpp::Client::TokenExpirationCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_TokenExpirationCallback callback__native = [](void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        userData__typed->delegate();
    };
    Discord_Client_SetTokenExpirationCallback(
      &instance_, callback__native, Tcallback__UserData::Free, callback__userData);
}
void Client::UnmergeIntoProvisionalAccount(
  uint64_t applicationId,
  discordpp::AuthenticationExternalAuthType externalAuthType,
  std::string const& externalAuthToken,
  discordpp::Client::UnmergeIntoProvisionalAccountCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String externalAuthToken__str{(uint8_t*)(externalAuthToken.data()),
                                          externalAuthToken.size()};
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_UnmergeIntoProvisionalAccountCallback callback__native = [](auto result,
                                                                               void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_UnmergeIntoProvisionalAccount(
      &instance_,
      applicationId,
      static_cast<Discord_AuthenticationExternalAuthType>(externalAuthType),
      externalAuthToken__str,
      callback__native,
      Tcallback__UserData::Free,
      callback__userData);
}
void Client::UpdateProvisionalAccountDisplayName(
  std::string const& name,
  discordpp::Client::UpdateProvisionalAccountDisplayNameCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String name__str{(uint8_t*)(name.data()), name.size()};
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_UpdateProvisionalAccountDisplayNameCallback callback__native =
      [](auto result, void* userData__) {
          auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          userData__typed->delegate(std::move(result__obj));
      };
    Discord_Client_UpdateProvisionalAccountDisplayName(
      &instance_, name__str, callback__native, Tcallback__UserData::Free, callback__userData);
}
void Client::UpdateToken(discordpp::AuthorizationTokenType tokenType,
                         std::string token,
                         discordpp::Client::UpdateTokenCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String token__str{(uint8_t*)(token.data()), token.size()};
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_UpdateTokenCallback callback__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_UpdateToken(&instance_,
                               static_cast<Discord_AuthorizationTokenType>(tokenType),
                               token__str,
                               callback__native,
                               Tcallback__UserData::Free,
                               callback__userData);
}
bool Client::CanOpenMessageInDiscord(uint64_t messageId)
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ = Discord_Client_CanOpenMessageInDiscord(&instance_, messageId);
    return returnValue__;
}
void Client::DeleteUserMessage(uint64_t recipientId,
                               uint64_t messageId,
                               discordpp::Client::DeleteUserMessageCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_DeleteUserMessageCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_DeleteUserMessage(
      &instance_, recipientId, messageId, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::EditUserMessage(uint64_t recipientId,
                             uint64_t messageId,
                             std::string const& content,
                             discordpp::Client::EditUserMessageCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String content__str{(uint8_t*)(content.data()), content.size()};
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_EditUserMessageCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_EditUserMessage(&instance_,
                                   recipientId,
                                   messageId,
                                   content__str,
                                   cb__native,
                                   Tcb__UserData::Free,
                                   cb__userData);
}
std::optional<discordpp::ChannelHandle> Client::GetChannelHandle(uint64_t channelId) const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_ChannelHandle returnValueNative__;
    returnIsNonNull__ =
      Discord_Client_GetChannelHandle(&instance_, channelId, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::ChannelHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
void Client::GetLobbyMessagesWithLimit(uint64_t lobbyId,
                                       int32_t limit,
                                       discordpp::Client::GetLobbyMessagesCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_GetLobbyMessagesCallback cb__native =
      [](auto result, auto messages, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          std::vector<discordpp::MessageHandle> messages__vec;
          messages__vec.reserve(messages.size);
          for (size_t i__ = 0; i__ < messages.size; ++i__) {
              messages__vec.emplace_back(messages.ptr[i__], DiscordObjectState::Owned);
          }
          Discord_Free(messages.ptr);
          userData__typed->delegate(std::move(result__obj), std::move(messages__vec));
      };
    Discord_Client_GetLobbyMessagesWithLimit(
      &instance_, lobbyId, limit, cb__native, Tcb__UserData::Free, cb__userData);
}
std::optional<discordpp::MessageHandle> Client::GetMessageHandle(uint64_t messageId) const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_MessageHandle returnValueNative__;
    returnIsNonNull__ =
      Discord_Client_GetMessageHandle(&instance_, messageId, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::MessageHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
void Client::GetUserMessageSummaries(discordpp::Client::UserMessageSummariesCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UserMessageSummariesCallback cb__native =
      [](auto result, auto summaries, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          std::vector<discordpp::UserMessageSummary> summaries__vec;
          summaries__vec.reserve(summaries.size);
          for (size_t i__ = 0; i__ < summaries.size; ++i__) {
              summaries__vec.emplace_back(summaries.ptr[i__], DiscordObjectState::Owned);
          }
          Discord_Free(summaries.ptr);
          userData__typed->delegate(std::move(result__obj), std::move(summaries__vec));
      };
    Discord_Client_GetUserMessageSummaries(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::GetUserMessagesWithLimit(uint64_t recipientId,
                                      int32_t limit,
                                      discordpp::Client::UserMessagesWithLimitCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UserMessagesWithLimitCallback cb__native =
      [](auto result, auto messages, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          std::vector<discordpp::MessageHandle> messages__vec;
          messages__vec.reserve(messages.size);
          for (size_t i__ = 0; i__ < messages.size; ++i__) {
              messages__vec.emplace_back(messages.ptr[i__], DiscordObjectState::Owned);
          }
          Discord_Free(messages.ptr);
          userData__typed->delegate(std::move(result__obj), std::move(messages__vec));
      };
    Discord_Client_GetUserMessagesWithLimit(
      &instance_, recipientId, limit, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::OpenMessageInDiscord(
  uint64_t messageId,
  discordpp::Client::ProvisionalUserMergeRequiredCallback provisionalUserMergeRequiredCallback,
  discordpp::Client::OpenMessageInDiscordCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using TprovisionalUserMergeRequiredCallback__UserData =
      TDelegateUserData<std::remove_reference_t<decltype(provisionalUserMergeRequiredCallback)>>;
    auto provisionalUserMergeRequiredCallback__userData =
      new TprovisionalUserMergeRequiredCallback__UserData(provisionalUserMergeRequiredCallback);
    Discord_Client_ProvisionalUserMergeRequiredCallback
      provisionalUserMergeRequiredCallback__native = [](void* userData__) {
          auto userData__typed =
            static_cast<TprovisionalUserMergeRequiredCallback__UserData*>(userData__);
          userData__typed->delegate();
      };
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_OpenMessageInDiscordCallback callback__native = [](auto result,
                                                                      void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_OpenMessageInDiscord(&instance_,
                                        messageId,
                                        provisionalUserMergeRequiredCallback__native,
                                        TprovisionalUserMergeRequiredCallback__UserData::Free,
                                        provisionalUserMergeRequiredCallback__userData,
                                        callback__native,
                                        Tcallback__UserData::Free,
                                        callback__userData);
}
void Client::SendLobbyMessage(uint64_t lobbyId,
                              std::string const& content,
                              discordpp::Client::SendUserMessageCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String content__str{(uint8_t*)(content.data()), content.size()};
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_SendUserMessageCallback cb__native =
      [](auto result, auto messageId, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          userData__typed->delegate(std::move(result__obj), messageId);
      };
    Discord_Client_SendLobbyMessage(
      &instance_, lobbyId, content__str, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SendLobbyMessageWithMetadata(
  uint64_t lobbyId,
  std::string const& content,
  std::unordered_map<std::string, std::string> const& metadata,
  discordpp::Client::SendUserMessageCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String content__str{(uint8_t*)(content.data()), content.size()};
    ConvertedProperties metadata__convert(metadata);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_SendUserMessageCallback cb__native =
      [](auto result, auto messageId, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          userData__typed->delegate(std::move(result__obj), messageId);
      };
    Discord_Client_SendLobbyMessageWithMetadata(&instance_,
                                                lobbyId,
                                                content__str,
                                                metadata__convert.Properties,
                                                cb__native,
                                                Tcb__UserData::Free,
                                                cb__userData);
}
void Client::SendUserMessage(uint64_t recipientId,
                             std::string const& content,
                             discordpp::Client::SendUserMessageCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String content__str{(uint8_t*)(content.data()), content.size()};
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_SendUserMessageCallback cb__native =
      [](auto result, auto messageId, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          userData__typed->delegate(std::move(result__obj), messageId);
      };
    Discord_Client_SendUserMessage(
      &instance_, recipientId, content__str, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SendUserMessageWithMetadata(
  uint64_t recipientId,
  std::string const& content,
  std::unordered_map<std::string, std::string> const& metadata,
  discordpp::Client::SendUserMessageCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String content__str{(uint8_t*)(content.data()), content.size()};
    ConvertedProperties metadata__convert(metadata);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_SendUserMessageCallback cb__native =
      [](auto result, auto messageId, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          userData__typed->delegate(std::move(result__obj), messageId);
      };
    Discord_Client_SendUserMessageWithMetadata(&instance_,
                                               recipientId,
                                               content__str,
                                               metadata__convert.Properties,
                                               cb__native,
                                               Tcb__UserData::Free,
                                               cb__userData);
}
void Client::SetMessageCreatedCallback(discordpp::Client::MessageCreatedCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_MessageCreatedCallback cb__native = [](auto messageId, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        userData__typed->delegate(messageId);
    };
    Discord_Client_SetMessageCreatedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetMessageDeletedCallback(discordpp::Client::MessageDeletedCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_MessageDeletedCallback cb__native =
      [](auto messageId, auto channelId, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          userData__typed->delegate(messageId, channelId);
      };
    Discord_Client_SetMessageDeletedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetMessageUpdatedCallback(discordpp::Client::MessageUpdatedCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_MessageUpdatedCallback cb__native = [](auto messageId, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        userData__typed->delegate(messageId);
    };
    Discord_Client_SetMessageUpdatedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetShowingChat(bool showingChat)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetShowingChat(&instance_, showingChat);
}
void Client::AddLogCallback(discordpp::Client::LogCallback callback,
                            discordpp::LoggingSeverity minSeverity)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_LogCallback callback__native = [](
                                                    auto message, auto severity, void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        std::string message__str(reinterpret_cast<char*>(message.ptr), message.size);
        userData__typed->delegate(std::move(message__str),
                                  static_cast<discordpp::LoggingSeverity>(severity));
        Discord_Free(message.ptr);
    };
    Discord_Client_AddLogCallback(&instance_,
                                  callback__native,
                                  Tcallback__UserData::Free,
                                  callback__userData,
                                  static_cast<Discord_LoggingSeverity>(minSeverity));
}
void Client::AddVoiceLogCallback(discordpp::Client::LogCallback callback,
                                 discordpp::LoggingSeverity minSeverity)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_LogCallback callback__native = [](
                                                    auto message, auto severity, void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        std::string message__str(reinterpret_cast<char*>(message.ptr), message.size);
        userData__typed->delegate(std::move(message__str),
                                  static_cast<discordpp::LoggingSeverity>(severity));
        Discord_Free(message.ptr);
    };
    Discord_Client_AddVoiceLogCallback(&instance_,
                                       callback__native,
                                       Tcallback__UserData::Free,
                                       callback__userData,
                                       static_cast<Discord_LoggingSeverity>(minSeverity));
}
void Client::Connect()
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_Connect(&instance_);
}
void Client::Disconnect()
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_Disconnect(&instance_);
}
discordpp::Client::Status Client::GetStatus() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_Status returnValue__;
    returnValue__ = Discord_Client_GetStatus(&instance_);
    return static_cast<discordpp::Client::Status>(returnValue__);
}
void Client::OpenConnectedGamesSettingsInDiscord(
  discordpp::Client::OpenConnectedGamesSettingsInDiscordCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_OpenConnectedGamesSettingsInDiscordCallback callback__native =
      [](auto result, void* userData__) {
          auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          userData__typed->delegate(std::move(result__obj));
      };
    Discord_Client_OpenConnectedGamesSettingsInDiscord(
      &instance_, callback__native, Tcallback__UserData::Free, callback__userData);
}
void Client::SetApplicationId(uint64_t applicationId)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_SetApplicationId(&instance_, applicationId);
}
bool Client::SetLogDir(std::string const& path, discordpp::LoggingSeverity minSeverity)
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    Discord_String path__str{(uint8_t*)(path.data()), path.size()};
    returnValue__ = Discord_Client_SetLogDir(
      &instance_, path__str, static_cast<Discord_LoggingSeverity>(minSeverity));
    return returnValue__;
}
void Client::SetStatusChangedCallback(discordpp::Client::OnStatusChanged cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_OnStatusChanged cb__native =
      [](auto status, auto error, auto errorDetail, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          userData__typed->delegate(static_cast<discordpp::Client::Status>(status),
                                    static_cast<discordpp::Client::Error>(error),
                                    errorDetail);
      };
    Discord_Client_SetStatusChangedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetVoiceLogDir(std::string const& path, discordpp::LoggingSeverity minSeverity)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String path__str{(uint8_t*)(path.data()), path.size()};
    Discord_Client_SetVoiceLogDir(
      &instance_, path__str, static_cast<Discord_LoggingSeverity>(minSeverity));
}
void Client::CreateOrJoinLobby(std::string const& secret,
                               discordpp::Client::CreateOrJoinLobbyCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String secret__str{(uint8_t*)(secret.data()), secret.size()};
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_CreateOrJoinLobbyCallback callback__native =
      [](auto result, auto lobbyId, void* userData__) {
          auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          userData__typed->delegate(std::move(result__obj), lobbyId);
      };
    Discord_Client_CreateOrJoinLobby(
      &instance_, secret__str, callback__native, Tcallback__UserData::Free, callback__userData);
}
void Client::CreateOrJoinLobbyWithMetadata(
  std::string const& secret,
  std::unordered_map<std::string, std::string> const& lobbyMetadata,
  std::unordered_map<std::string, std::string> const& memberMetadata,
  discordpp::Client::CreateOrJoinLobbyCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String secret__str{(uint8_t*)(secret.data()), secret.size()};
    ConvertedProperties lobbyMetadata__convert(lobbyMetadata);
    ConvertedProperties memberMetadata__convert(memberMetadata);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_CreateOrJoinLobbyCallback callback__native =
      [](auto result, auto lobbyId, void* userData__) {
          auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          userData__typed->delegate(std::move(result__obj), lobbyId);
      };
    Discord_Client_CreateOrJoinLobbyWithMetadata(&instance_,
                                                 secret__str,
                                                 lobbyMetadata__convert.Properties,
                                                 memberMetadata__convert.Properties,
                                                 callback__native,
                                                 Tcallback__UserData::Free,
                                                 callback__userData);
}
void Client::GetGuildChannels(uint64_t guildId, discordpp::Client::GetGuildChannelsCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_GetGuildChannelsCallback cb__native =
      [](auto result, auto guildChannels, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          std::vector<discordpp::GuildChannel> guildChannels__vec;
          guildChannels__vec.reserve(guildChannels.size);
          for (size_t i__ = 0; i__ < guildChannels.size; ++i__) {
              guildChannels__vec.emplace_back(guildChannels.ptr[i__], DiscordObjectState::Owned);
          }
          Discord_Free(guildChannels.ptr);
          userData__typed->delegate(std::move(result__obj), std::move(guildChannels__vec));
      };
    Discord_Client_GetGuildChannels(
      &instance_, guildId, cb__native, Tcb__UserData::Free, cb__userData);
}
std::optional<discordpp::LobbyHandle> Client::GetLobbyHandle(uint64_t lobbyId) const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_LobbyHandle returnValueNative__;
    returnIsNonNull__ = Discord_Client_GetLobbyHandle(&instance_, lobbyId, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::LobbyHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
std::vector<uint64_t> Client::GetLobbyIds() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_UInt64Span returnValueNative__;
    Discord_Client_GetLobbyIds(&instance_, &returnValueNative__);
    std::vector<uint64_t> returnValue__(returnValueNative__.ptr,
                                        returnValueNative__.ptr + returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void Client::GetUserGuilds(discordpp::Client::GetUserGuildsCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_GetUserGuildsCallback cb__native =
      [](auto result, auto guilds, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          std::vector<discordpp::GuildMinimal> guilds__vec;
          guilds__vec.reserve(guilds.size);
          for (size_t i__ = 0; i__ < guilds.size; ++i__) {
              guilds__vec.emplace_back(guilds.ptr[i__], DiscordObjectState::Owned);
          }
          Discord_Free(guilds.ptr);
          userData__typed->delegate(std::move(result__obj), std::move(guilds__vec));
      };
    Discord_Client_GetUserGuilds(&instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::JoinLinkedLobbyGuild(
  uint64_t lobbyId,
  discordpp::Client::ProvisionalUserMergeRequiredCallback provisionalUserMergeRequiredCallback,
  discordpp::Client::JoinLinkedLobbyGuildCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using TprovisionalUserMergeRequiredCallback__UserData =
      TDelegateUserData<std::remove_reference_t<decltype(provisionalUserMergeRequiredCallback)>>;
    auto provisionalUserMergeRequiredCallback__userData =
      new TprovisionalUserMergeRequiredCallback__UserData(provisionalUserMergeRequiredCallback);
    Discord_Client_ProvisionalUserMergeRequiredCallback
      provisionalUserMergeRequiredCallback__native = [](void* userData__) {
          auto userData__typed =
            static_cast<TprovisionalUserMergeRequiredCallback__UserData*>(userData__);
          userData__typed->delegate();
      };
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_JoinLinkedLobbyGuildCallback callback__native =
      [](auto result, auto inviteUrl, void* userData__) {
          auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          std::string inviteUrl__str(reinterpret_cast<char*>(inviteUrl.ptr), inviteUrl.size);
          userData__typed->delegate(std::move(result__obj), std::move(inviteUrl__str));
          Discord_Free(inviteUrl.ptr);
      };
    Discord_Client_JoinLinkedLobbyGuild(&instance_,
                                        lobbyId,
                                        provisionalUserMergeRequiredCallback__native,
                                        TprovisionalUserMergeRequiredCallback__UserData::Free,
                                        provisionalUserMergeRequiredCallback__userData,
                                        callback__native,
                                        Tcallback__UserData::Free,
                                        callback__userData);
}
void Client::LeaveLobby(uint64_t lobbyId, discordpp::Client::LeaveLobbyCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_LeaveLobbyCallback callback__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_LeaveLobby(
      &instance_, lobbyId, callback__native, Tcallback__UserData::Free, callback__userData);
}
void Client::LinkChannelToLobby(uint64_t lobbyId,
                                uint64_t channelId,
                                discordpp::Client::LinkOrUnlinkChannelCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_LinkOrUnlinkChannelCallback callback__native = [](auto result,
                                                                     void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_LinkChannelToLobby(&instance_,
                                      lobbyId,
                                      channelId,
                                      callback__native,
                                      Tcallback__UserData::Free,
                                      callback__userData);
}
void Client::SetLobbyCreatedCallback(discordpp::Client::LobbyCreatedCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_LobbyCreatedCallback cb__native = [](auto lobbyId, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        userData__typed->delegate(lobbyId);
    };
    Discord_Client_SetLobbyCreatedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetLobbyDeletedCallback(discordpp::Client::LobbyDeletedCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_LobbyDeletedCallback cb__native = [](auto lobbyId, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        userData__typed->delegate(lobbyId);
    };
    Discord_Client_SetLobbyDeletedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetLobbyMemberAddedCallback(discordpp::Client::LobbyMemberAddedCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_LobbyMemberAddedCallback cb__native =
      [](auto lobbyId, auto memberId, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          userData__typed->delegate(lobbyId, memberId);
      };
    Discord_Client_SetLobbyMemberAddedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetLobbyMemberRemovedCallback(discordpp::Client::LobbyMemberRemovedCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_LobbyMemberRemovedCallback cb__native =
      [](auto lobbyId, auto memberId, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          userData__typed->delegate(lobbyId, memberId);
      };
    Discord_Client_SetLobbyMemberRemovedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetLobbyMemberUpdatedCallback(discordpp::Client::LobbyMemberUpdatedCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_LobbyMemberUpdatedCallback cb__native =
      [](auto lobbyId, auto memberId, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          userData__typed->delegate(lobbyId, memberId);
      };
    Discord_Client_SetLobbyMemberUpdatedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetLobbyUpdatedCallback(discordpp::Client::LobbyUpdatedCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_LobbyUpdatedCallback cb__native = [](auto lobbyId, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        userData__typed->delegate(lobbyId);
    };
    Discord_Client_SetLobbyUpdatedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::UnlinkChannelFromLobby(uint64_t lobbyId,
                                    discordpp::Client::LinkOrUnlinkChannelCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_LinkOrUnlinkChannelCallback callback__native = [](auto result,
                                                                     void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_UnlinkChannelFromLobby(
      &instance_, lobbyId, callback__native, Tcallback__UserData::Free, callback__userData);
}
void Client::IsDiscordAppInstalled(discordpp::Client::IsDiscordAppInstalledCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_IsDiscordAppInstalledCallback callback__native = [](auto installed,
                                                                       void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        userData__typed->delegate(installed);
    };
    Discord_Client_IsDiscordAppInstalled(
      &instance_, callback__native, Tcallback__UserData::Free, callback__userData);
}
void Client::AcceptActivityInvite(discordpp::ActivityInvite invite,
                                  discordpp::Client::AcceptActivityInviteCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_AcceptActivityInviteCallback cb__native =
      [](auto result, auto joinSecret, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          std::string joinSecret__str(reinterpret_cast<char*>(joinSecret.ptr), joinSecret.size);
          userData__typed->delegate(std::move(result__obj), std::move(joinSecret__str));
          Discord_Free(joinSecret.ptr);
      };
    Discord_Client_AcceptActivityInvite(
      &instance_, invite.instance(), cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::ClearRichPresence()
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_Client_ClearRichPresence(&instance_);
}
bool Client::RegisterLaunchCommand(uint64_t applicationId, std::string command)
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    Discord_String command__str{(uint8_t*)(command.data()), command.size()};
    returnValue__ = Discord_Client_RegisterLaunchCommand(&instance_, applicationId, command__str);
    return returnValue__;
}
bool Client::RegisterLaunchSteamApplication(uint64_t applicationId, uint32_t steamAppId)
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnValue__;
    returnValue__ =
      Discord_Client_RegisterLaunchSteamApplication(&instance_, applicationId, steamAppId);
    return returnValue__;
}
void Client::SendActivityInvite(uint64_t userId,
                                std::string const& content,
                                discordpp::Client::SendActivityInviteCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String content__str{(uint8_t*)(content.data()), content.size()};
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_SendActivityInviteCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_SendActivityInvite(
      &instance_, userId, content__str, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SendActivityJoinRequest(uint64_t userId,
                                     discordpp::Client::SendActivityInviteCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_SendActivityInviteCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_SendActivityJoinRequest(
      &instance_, userId, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SendActivityJoinRequestReply(discordpp::ActivityInvite invite,
                                          discordpp::Client::SendActivityInviteCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_SendActivityInviteCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_SendActivityJoinRequestReply(
      &instance_, invite.instance(), cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetActivityInviteCreatedCallback(discordpp::Client::ActivityInviteCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_ActivityInviteCallback cb__native = [](auto invite, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ActivityInvite invite__obj(*invite, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(invite__obj));
    };
    Discord_Client_SetActivityInviteCreatedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetActivityInviteUpdatedCallback(discordpp::Client::ActivityInviteCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_ActivityInviteCallback cb__native = [](auto invite, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ActivityInvite invite__obj(*invite, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(invite__obj));
    };
    Discord_Client_SetActivityInviteUpdatedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetActivityJoinCallback(discordpp::Client::ActivityJoinCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_ActivityJoinCallback cb__native = [](auto joinSecret, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        std::string joinSecret__str(reinterpret_cast<char*>(joinSecret.ptr), joinSecret.size);
        userData__typed->delegate(std::move(joinSecret__str));
        Discord_Free(joinSecret.ptr);
    };
    Discord_Client_SetActivityJoinCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetActivityJoinWithApplicationCallback(
  discordpp::Client::ActivityJoinWithApplicationCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_ActivityJoinWithApplicationCallback cb__native =
      [](auto applicationId, auto joinSecret, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          std::string joinSecret__str(reinterpret_cast<char*>(joinSecret.ptr), joinSecret.size);
          userData__typed->delegate(applicationId, std::move(joinSecret__str));
          Discord_Free(joinSecret.ptr);
      };
    Discord_Client_SetActivityJoinWithApplicationCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetOnlineStatus(discordpp::StatusType status,
                             discordpp::Client::UpdateStatusCallback callback)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_UpdateStatusCallback callback__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_SetOnlineStatus(&instance_,
                                   static_cast<Discord_StatusType>(status),
                                   callback__native,
                                   Tcallback__UserData::Free,
                                   callback__userData);
}
void Client::UpdateRichPresence(discordpp::Activity activity,
                                discordpp::Client::UpdateRichPresenceCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UpdateRichPresenceCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_UpdateRichPresence(
      &instance_, activity.instance(), cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::AcceptDiscordFriendRequest(uint64_t userId,
                                        discordpp::Client::UpdateRelationshipCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UpdateRelationshipCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_AcceptDiscordFriendRequest(
      &instance_, userId, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::AcceptGameFriendRequest(uint64_t userId,
                                     discordpp::Client::UpdateRelationshipCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UpdateRelationshipCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_AcceptGameFriendRequest(
      &instance_, userId, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::BlockUser(uint64_t userId, discordpp::Client::UpdateRelationshipCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UpdateRelationshipCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_BlockUser(&instance_, userId, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::CancelDiscordFriendRequest(uint64_t userId,
                                        discordpp::Client::UpdateRelationshipCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UpdateRelationshipCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_CancelDiscordFriendRequest(
      &instance_, userId, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::CancelGameFriendRequest(uint64_t userId,
                                     discordpp::Client::UpdateRelationshipCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UpdateRelationshipCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_CancelGameFriendRequest(
      &instance_, userId, cb__native, Tcb__UserData::Free, cb__userData);
}
discordpp::RelationshipHandle Client::GetRelationshipHandle(uint64_t userId) const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_RelationshipHandle returnValueNative__{};
    Discord_Client_GetRelationshipHandle(&instance_, userId, &returnValueNative__);
    discordpp::RelationshipHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
std::vector<discordpp::RelationshipHandle> Client::GetRelationships() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_RelationshipHandleSpan returnValueNative__;
    Discord_Client_GetRelationships(&instance_, &returnValueNative__);
    std::vector<discordpp::RelationshipHandle> returnValue__;
    returnValue__.reserve(returnValueNative__.size);
    for (size_t i__ = 0; i__ < returnValueNative__.size; ++i__) {
        returnValue__.emplace_back(returnValueNative__.ptr[i__], DiscordObjectState::Owned);
    }
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::vector<discordpp::RelationshipHandle> Client::GetRelationshipsByGroup(
  discordpp::RelationshipGroupType groupType) const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_RelationshipHandleSpan returnValueNative__;
    Discord_Client_GetRelationshipsByGroup(
      &instance_, static_cast<Discord_RelationshipGroupType>(groupType), &returnValueNative__);
    std::vector<discordpp::RelationshipHandle> returnValue__;
    returnValue__.reserve(returnValueNative__.size);
    for (size_t i__ = 0; i__ < returnValueNative__.size; ++i__) {
        returnValue__.emplace_back(returnValueNative__.ptr[i__], DiscordObjectState::Owned);
    }
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void Client::RejectDiscordFriendRequest(uint64_t userId,
                                        discordpp::Client::UpdateRelationshipCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UpdateRelationshipCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_RejectDiscordFriendRequest(
      &instance_, userId, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::RejectGameFriendRequest(uint64_t userId,
                                     discordpp::Client::UpdateRelationshipCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UpdateRelationshipCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_RejectGameFriendRequest(
      &instance_, userId, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::RemoveDiscordAndGameFriend(uint64_t userId,
                                        discordpp::Client::UpdateRelationshipCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UpdateRelationshipCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_RemoveDiscordAndGameFriend(
      &instance_, userId, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::RemoveGameFriend(uint64_t userId, discordpp::Client::UpdateRelationshipCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UpdateRelationshipCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_RemoveGameFriend(
      &instance_, userId, cb__native, Tcb__UserData::Free, cb__userData);
}
std::vector<discordpp::UserHandle> Client::SearchFriendsByUsername(std::string searchStr) const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_UserHandleSpan returnValueNative__;
    Discord_String searchStr__str{(uint8_t*)(searchStr.data()), searchStr.size()};
    Discord_Client_SearchFriendsByUsername(&instance_, searchStr__str, &returnValueNative__);
    std::vector<discordpp::UserHandle> returnValue__;
    returnValue__.reserve(returnValueNative__.size);
    for (size_t i__ = 0; i__ < returnValueNative__.size; ++i__) {
        returnValue__.emplace_back(returnValueNative__.ptr[i__], DiscordObjectState::Owned);
    }
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
void Client::SendDiscordFriendRequest(std::string const& username,
                                      discordpp::Client::SendFriendRequestCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String username__str{(uint8_t*)(username.data()), username.size()};
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_SendFriendRequestCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_SendDiscordFriendRequest(
      &instance_, username__str, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SendDiscordFriendRequestById(uint64_t userId,
                                          discordpp::Client::UpdateRelationshipCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UpdateRelationshipCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_SendDiscordFriendRequestById(
      &instance_, userId, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SendGameFriendRequest(std::string const& username,
                                   discordpp::Client::SendFriendRequestCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_String username__str{(uint8_t*)(username.data()), username.size()};
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_SendFriendRequestCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_SendGameFriendRequest(
      &instance_, username__str, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SendGameFriendRequestById(uint64_t userId,
                                       discordpp::Client::UpdateRelationshipCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UpdateRelationshipCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_SendGameFriendRequestById(
      &instance_, userId, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetRelationshipCreatedCallback(discordpp::Client::RelationshipCreatedCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_RelationshipCreatedCallback cb__native =
      [](auto userId, auto isDiscordRelationshipUpdate, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          userData__typed->delegate(userId, isDiscordRelationshipUpdate);
      };
    Discord_Client_SetRelationshipCreatedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetRelationshipDeletedCallback(discordpp::Client::RelationshipDeletedCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_RelationshipDeletedCallback cb__native =
      [](auto userId, auto isDiscordRelationshipUpdate, void* userData__) {
          auto userData__typed = static_cast<Tcb__UserData*>(userData__);
          userData__typed->delegate(userId, isDiscordRelationshipUpdate);
      };
    Discord_Client_SetRelationshipDeletedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::UnblockUser(uint64_t userId, discordpp::Client::UpdateRelationshipCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UpdateRelationshipCallback cb__native = [](auto result, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
        userData__typed->delegate(std::move(result__obj));
    };
    Discord_Client_UnblockUser(&instance_, userId, cb__native, Tcb__UserData::Free, cb__userData);
}
std::optional<discordpp::UserHandle> Client::GetCurrentUserV2() const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_UserHandle returnValueNative__;
    returnIsNonNull__ = Discord_Client_GetCurrentUserV2(&instance_, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::UserHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
void Client::GetDiscordClientConnectedUser(
  uint64_t applicationId,
  discordpp::Client::GetDiscordClientConnectedUserCallback callback) const
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcallback__UserData = TDelegateUserData<std::remove_reference_t<decltype(callback)>>;
    auto callback__userData = new Tcallback__UserData(callback);
    Discord_Client_GetDiscordClientConnectedUserCallback callback__native =
      [](auto result, auto user, void* userData__) {
          auto userData__typed = static_cast<Tcallback__UserData*>(userData__);
          discordpp::ClientResult result__obj(*result, DiscordObjectState::Owned);
          std::optional<discordpp::UserHandle> user__opt{};
          if (user) {
              user__opt = discordpp::UserHandle(*user, DiscordObjectState::Owned);
          }
          userData__typed->delegate(std::move(result__obj), std::move(user__opt));
      };
    Discord_Client_GetDiscordClientConnectedUser(
      &instance_, applicationId, callback__native, Tcallback__UserData::Free, callback__userData);
}
std::optional<discordpp::UserHandle> Client::GetUser(uint64_t userId) const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_UserHandle returnValueNative__;
    returnIsNonNull__ = Discord_Client_GetUser(&instance_, userId, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::UserHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
void Client::SetRelationshipGroupsUpdatedCallback(
  discordpp::Client::RelationshipGroupsUpdatedCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_RelationshipGroupsUpdatedCallback cb__native = [](auto userId,
                                                                     void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        userData__typed->delegate(userId);
    };
    Discord_Client_SetRelationshipGroupsUpdatedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
void Client::SetUserUpdatedCallback(discordpp::Client::UserUpdatedCallback cb)
{
    assert(state_ == DiscordObjectState::Owned);
    using Tcb__UserData = TDelegateUserData<std::remove_reference_t<decltype(cb)>>;
    auto cb__userData = new Tcb__UserData(cb);
    Discord_Client_UserUpdatedCallback cb__native = [](auto userId, void* userData__) {
        auto userData__typed = static_cast<Tcb__UserData*>(userData__);
        userData__typed->delegate(userId);
    };
    Discord_Client_SetUserUpdatedCallback(
      &instance_, cb__native, Tcb__UserData::Free, cb__userData);
}
const CallInfoHandle CallInfoHandle::nullobj{{}, DiscordObjectState::Invalid};
CallInfoHandle::~CallInfoHandle()
{
    if (state_ == DiscordObjectState::Owned) {
        Drop();
        state_ = DiscordObjectState::Invalid;
    }
}
CallInfoHandle::CallInfoHandle(CallInfoHandle&& other) noexcept
  : instance_(other.instance_)
  , state_(other.state_)
{
    other.state_ = DiscordObjectState::Invalid;
}
CallInfoHandle& CallInfoHandle::operator=(CallInfoHandle&& other) noexcept
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
        }
        instance_ = other.instance_;
        state_ = other.state_;
        other.state_ = DiscordObjectState::Invalid;
    }
    return *this;
}
CallInfoHandle::CallInfoHandle(const CallInfoHandle& other)
  : instance_{}
  , state_(DiscordObjectState::Invalid)
{
    if (other.state_ == DiscordObjectState::Owned) {
        Discord_CallInfoHandle_Clone(&instance_, other.instance());

        state_ = DiscordObjectState::Owned;
    }
}
CallInfoHandle& CallInfoHandle::operator=(const CallInfoHandle& other)
{
    if (this != &other) {
        if (state_ == DiscordObjectState::Owned) {
            Drop();
            state_ = DiscordObjectState::Invalid;
        }
        if (other.state_ == DiscordObjectState::Owned) {
            Discord_CallInfoHandle_Clone(&instance_, other.instance());

            state_ = DiscordObjectState::Owned;
        }
    }
    return *this;
}
CallInfoHandle::CallInfoHandle(Discord_CallInfoHandle instance, DiscordObjectState state)
  : instance_(instance)
  , state_(state)
{
}
void CallInfoHandle::Drop()
{
    if (state_ != DiscordObjectState::Owned) {
        return;
    }
    Discord_CallInfoHandle_Drop(&instance_);
    state_ = DiscordObjectState::Invalid;
}
uint64_t CallInfoHandle::ChannelId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_CallInfoHandle_ChannelId(&instance_);
    return returnValue__;
}
std::vector<uint64_t> CallInfoHandle::GetParticipants() const
{
    assert(state_ == DiscordObjectState::Owned);
    Discord_UInt64Span returnValueNative__;
    Discord_CallInfoHandle_GetParticipants(&instance_, &returnValueNative__);
    std::vector<uint64_t> returnValue__(returnValueNative__.ptr,
                                        returnValueNative__.ptr + returnValueNative__.size);
    Discord_Free(returnValueNative__.ptr);
    return returnValue__;
}
std::optional<discordpp::VoiceStateHandle> CallInfoHandle::GetVoiceStateHandle(
  uint64_t userId) const
{
    assert(state_ == DiscordObjectState::Owned);
    bool returnIsNonNull__;
    Discord_VoiceStateHandle returnValueNative__;
    returnIsNonNull__ =
      Discord_CallInfoHandle_GetVoiceStateHandle(&instance_, userId, &returnValueNative__);
    if (!returnIsNonNull__) {
        return {};
    }
    discordpp::VoiceStateHandle returnValue__(returnValueNative__, DiscordObjectState::Owned);
    return returnValue__;
}
uint64_t CallInfoHandle::GuildId() const
{
    assert(state_ == DiscordObjectState::Owned);
    uint64_t returnValue__;
    returnValue__ = Discord_CallInfoHandle_GuildId(&instance_);
    return returnValue__;
}
}

#endif
