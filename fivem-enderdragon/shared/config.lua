Config = {
    AnchorModel = 'prop_poolball_1', -- invisible local CObject; visible geometry is the Minecraft model
    RequireAce = false, -- grant enderdragon.spawn when enabled
    MaxDragons = 2, MaxDragonsPerPlayer = 1, SpawnCooldownMs = 5000,
    SpawnForward = 40.0, SpawnHeight = 30.0,
    ModelScale = 0.10, -- 24.8m fully extended wingspan; customize here
    Health = 1200, BulletDamage = 14, MeleeDamage = 35, HeadDamageMultiplier = 2.0,
    DamageIntervalMs = 140, DeathDurationMs = 4500,
    Flight = {
        OrbitRadius = 42.0, CruiseSpeed = 12.0, SwoopSpeed = 17.0,
        TurnSpeed = 50.0, VerticalSpeed = 9.0, ArenaRadius = 120.0,
        SwoopIntervalMs = 11000, SwoopDurationMs = 5000, RecoverMs = 3500,
        SwoopHeight = 0.75, GroundClearance = 2.0, BodyProbeRadius = 2.0,
        FlapsPerSecond = 0.7
    },
    TargetRange = 120.0, TargetScanMs = 600, MaxLosCandidates = 8,
    PreferPlayers = true, TargetNpcPeds = true,
    ChargeMs = 900, AttackCooldownMs = 5000,
    AmbientMinMs = 7000, AmbientMaxMs = 14000,
    RenderDistance = 300.0, SyncIntervalMs = 100, SnapshotIntervalMs = 3000, OwnerTimeoutMs = 15000,
    VehicleContact = {
        Enabled = true, ScanMs = 75, Range = 40.0, RetryMs = 500,
        TimeoutMs = 5000, CooldownMs = 10000, MaxReportsPerSecond = 12
    },
    Fireball = { Speed = 14.0, Radius = 0.45, SpriteSize = 1.2, LifetimeMs = 14000, MaxActive = 12 },
    Breath = { Radius = 5.0, Height = 3.5, DurationMs = 9000, TickMs = 500, Damage = 9, MaxActive = 16 },
    Audio = { Distance = 180.0, Volume = 0.8, MaxVoices = 24 },
    Debug = false
}
