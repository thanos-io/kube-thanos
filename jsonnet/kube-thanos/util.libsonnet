{
  withOptionalArgs(config, flagsToKeysMap)::
    [
      '--%s=%s' % [flag, config[flagsToKeysMap[flag]]]
      for flag in std.objectFields(flagsToKeysMap)
      if config[flagsToKeysMap[flag]] != null
    ],
}
