{ config, ... }:
{
  users.groups.redis = { };
  users.users.redis = {
    isSystemUser = true;
    description = "Redis user";
    group = "redis";
  };

  age.secrets.redis-password = {
    owner = "redis";
    generator.script = "alnum";
  };

  services.redis.servers.default = {
    enable = true;
    requirePassFile = config.age.secrets.redis-password.path;
    bind = "0.0.0.0";
    port = 6379;
    user = "redis";
  };
}
