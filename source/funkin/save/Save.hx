package funkin.save;

import flixel.util.FlxSave;
import funkin.input.Controls.Device;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.play.scoring.Scoring;
import funkin.play.scoring.Scoring.ScoringRank;
import funkin.save.migrator.RawSaveData_v1_0_0;
import funkin.save.migrator.SaveDataMigrator;
import funkin.ui.debug.charting.ChartEditorState.ChartEditorLiveInputStyle;
import funkin.ui.debug.charting.ChartEditorState.ChartEditorTheme;
import funkin.ui.debug.stageeditor.StageEditorState.StageEditorTheme;
import funkin.util.FileUtil;
import funkin.util.macro.ConsoleMacro;
import funkin.util.macro.SaveMacro;
import funkin.util.SerializerUtil;
import funkin.mobile.ui.FunkinHitbox;
import thx.semver.Version;
#if FEATURE_NEWGROUNDS
import funkin.api.newgrounds.Medals;
import funkin.api.newgrounds.Leaderboards;
#end

@:nullSafety @:build(funkin.util.macro.SaveMacro.buildSaveProperties())
class Save implements ConsoleClass
{
  public static final SAVE_DATA_VERSION:thx.semver.Version = "2.1.1";
  public static final SAVE_DATA_VERSION_RULE:thx.semver.VersionRule = ">=2.1.0 <2.2.0";
  public static var system:SaveSystem = new SaveSystem();

  static final DEFAULT_DIFFICULTIES:Array<String> = ['easy', 'normal', 'hard'];

  public static var instance(get, never):Save;

  static var _instance:Null<Save> = null;

  static function get_instance():Save
  {
    if (_instance == null) return load();
    return _instance;
  }

  var data:RawSaveData;

  public static function load():Save
  {
    final loadedSave:Save = loadFromSlot(Constants.BASE_SAVE_SLOT);
    _instance ??= loadedSave;

    return loadedSave;
  }

  public static function clearData():Void
  {
    _instance = Save.system.clearSlot(Constants.BASE_SAVE_SLOT);
  }

  @:nullSafety(Off)
  public function new(?data:RawSaveData)
  {
    this.data = data ??= Save.getDefaultData();

    #if mobile
    sanitizeMobileOptions();
    #end

    updateVersionToLatest();
  }

  public static function getDefaultData():RawSaveData
  {
    #if mobile
    var refreshRate:Int = FlxG.stage.window.displayMode.refreshRate;
    if (refreshRate < 60) refreshRate = 60;
    #end
    return {
      version: thx.Dynamics.clone(Save.SAVE_DATA_VERSION),
      volume: 1.0,
      mute: false,
      api: {
        newgrounds: {
          sessionId: null,
        }
      },
      scores: {
        levels: [],
        songs: [],
      },
      favoriteSongs: [],
      options: {
        framerate: #if mobile refreshRate #else 60 #end,
        naughtyness: true,
        downscroll: false,
        flashingLights: true,
        zoomCamera: true,
        debugDisplay: 'Off',
        debugDisplayBGOpacity: 50,
        subtitles: true,
        hapticsMode: 'All',
        hapticsIntensityMultiplier: 1,
        autoPause: true,
        vsyncMode: 'Off',
        strumlineBackgroundOpacity: 0,
        autoFullscreen: false,
        globalOffset: 0,
        audioVisualOffset: 0,
        unlockedFramerate: false,
        enabledDiscordRPC: true,
        screenshot: {
          shouldHideMouse: true,
          fancyPreview: true,
          previewOnSave: true,
        },
        controls: {
          p1: {
            keyboard: {
            },
            gamepad: {
            },
          },
          p2: {
            keyboard: {
            },
            gamepad: {
            },
          },
        },
      },
      #if mobile
      mobileOptions: {
        screenTimeout: false,
        controlsScheme: FunkinHitboxControlSchemes.FourLanes,
        noAds: false
      },
      #end
      mods: {
        enabledMods: [],
        modOptions: [],
      },
      unlocks: {
        charactersSeen: ["bf"],
        oldChar: false
      },
      optionsChartEditor: {
        previousFiles: [],
        noteQuant: 3,
        chartEditorLiveInputStyle: ChartEditorLiveInputStyle.None,
        theme: ChartEditorTheme.Light,
        playtestStartTime: false,
        playtestAudioSettings: false,
        playtestResultsSettings: false,
        downscroll: false,
        showNoteKinds: true,
        metronomeVolume: 1.0,
        hitsoundVolumePlayer: 1.0,
        hitsoundVolumeOpponent: 1.0,
        instVolume: 1.0,
        playerVoiceVolume: 1.0,
        opponentVoiceVolume: 1.0,
        playbackSpeed: 0.5,
        themeMusic: true
      },
      optionsStageEditor: {
        previousFiles: [],
        moveStep: "1px",
        angleStep: 5,
        theme: StageEditorTheme.Light,
        bfChar: "bf",
        gfChar: "gf",
        dadChar: "dad"
      }
    };
  }

  #if mobile
  @:nullSafety(Off)
  function sanitizeMobileOptions():Void
  {
    if (data.mobileOptions == null)
    {
      data.mobileOptions = {
        screenTimeout: false,
        controlsScheme: FunkinHitboxControlSchemes.FourLanes,
        noAds: false
      };
      return;
    }

    data.mobileOptions.controlsScheme = FunkinHitboxControlSchemes.resolve(data.mobileOptions.controlsScheme);
  }
  #end

  public var options(get, never):SaveDataOptions;

  function get_options():SaveDataOptions
  {
    return data.options;
  }

  #if mobile
  public var mobileOptions(get, never):SaveDataMobileOptions;

  function get_mobileOptions():SaveDataMobileOptions
  {
    return data.mobileOptions;
  }
  #end

  public var modOptions(get, never):Map<String, Dynamic>;

  function get_modOptions():Map<String, Dynamic>
  {
    return data.mods.modOptions;
  }

  @:saveProperty(data.volume)
  public var volume:SaveProperty<Float>;

  @:saveProperty(data.mute)
  public var mute:SaveProperty<Bool>;

  @:saveProperty(data.api.newgrounds.sessionId)
  public var ngSessionId:SaveProperty<Null<String>>;

  @:saveProperty(data.mods.enabledMods)
  public var enabledModDirs:SaveProperty<Array<String>>;

  @:saveProperty(data.optionsChartEditor.previousFiles, [])
  public var chartEditorPreviousFiles:SaveProperty<Array<String>>;
  @:saveProperty(data.optionsChartEditor.hasBackup, false)
  public var chartEditorHasBackup:SaveProperty<Bool>;
  @:saveProperty(data.optionsChartEditor.noteQuant, 3)
  public var chartEditorNoteQuant:SaveProperty<Int>;
  @:saveProperty(data.optionsChartEditor.chartEditorLiveInputStyle, ChartEditorLiveInputStyle.None)
  public var chartEditorLiveInputStyle:SaveProperty<ChartEditorLiveInputStyle>;
  @:saveProperty(data.optionsChartEditor.downscroll, false)
  public var chartEditorDownscroll:SaveProperty<Bool>;
  @:saveProperty(data.optionsChartEditor.showNoteKinds, true)
  public var chartEditorShowNoteKinds:SaveProperty<Bool>;
  @:saveProperty(data.optionsChartEditor.showSubtitles, true)
  public var chartEditorShowSubtitles:SaveProperty<Bool>;
  @:saveProperty(data.optionsChartEditor.playtestStartTime, false)
  public var chartEditorPlaytestStartTime:SaveProperty<Bool>;
  @:saveProperty(data.optionsChartEditor.playtestAudioSettings, false)
  public var chartEditorPlaytestAudioSettings:SaveProperty<Bool>;
  @:saveProperty(data.optionsChartEditor.playtestResultsSettings, false)
  public var chartEditorPlaytestResultsSettings:SaveProperty<Bool>;
  @:saveProperty(data.optionsChartEditor.theme, ChartEditorTheme.Light)
  public var chartEditorTheme:SaveProperty<ChartEditorTheme>;
  @:saveProperty(data.optionsChartEditor.metronomeVolume, 1.0)
  public var chartEditorMetronomeVolume:SaveProperty<Float>;
  @:saveProperty(data.optionsChartEditor.hitsoundVolumePlayer, 1.0)
  public var chartEditorHitsoundVolumePlayer:SaveProperty<Float>;
  @:saveProperty(data.optionsChartEditor.hitsoundVolumeOpponent, 1.0)
  public var chartEditorHitsoundVolumeOpponent:SaveProperty<Float>;
  @:saveProperty(data.optionsChartEditor.instVolume, 1.0)
  public var chartEditorInstVolume:SaveProperty<Float>;
  @:saveProperty(data.optionsChartEditor.playerVoiceVolume, 1.0)
  public var chartEditorPlayerVoiceVolume:SaveProperty<Float>;
  @:saveProperty(data.optionsChartEditor.opponentVoiceVolume, 1.0)
  public var chartEditorOpponentVoiceVolume:SaveProperty<Float>;
  @:saveProperty(data.optionsChartEditor.themeMusic, true)
  public var chartEditorThemeMusic:SaveProperty<Bool>;
  @:saveProperty(data.optionsChartEditor.playbackSpeed, 0.5)
  public var chartEditorPlaybackSpeed:SaveProperty<Float>;

  @:saveProperty(data.unlocks.charactersSeen, ["bf"])
  public var charactersSeen:SaveProperty<Array<String>>;

  @:saveProperty(data.unlocks.oldChar)
  public var oldChar:SaveProperty<Bool>;

  @:saveProperty(data.optionsStageEditor.previousFiles, [])
  public var stageEditorPreviousFiles:SaveProperty<Array<String>>;
  @:saveProperty(data.optionsStageEditor.hasBackup, false)
  public var stageEditorHasBackup:SaveProperty<Bool>;
  @:saveProperty(data.optionsStageEditor.moveStep, "1px")
  public var stageEditorMoveStep:SaveProperty<String>;
  @:saveProperty(data.optionsStageEditor.angleStep, 5.0)
  public var stageEditorAngleStep:SaveProperty<Float>;
  @:saveProperty(data.optionsStageEditor.theme, StageEditorTheme.Light)
  public var stageEditorTheme:SaveProperty<StageEditorTheme>;

  public var stageBoyfriendChar(get, set):String;

  function get_stageBoyfriendChar():String
  {
    if (data.optionsStageEditor.bfChar == null
      || CharacterDataParser.fetchCharacterData(data.optionsStageEditor.bfChar) == null) data.optionsStageEditor.bfChar = "bf";
    return data.optionsStageEditor.bfChar;
  }

  function set_stageBoyfriendChar(value:String):String
  {
    data.optionsStageEditor.bfChar = value;
    Save.system.flush();
    return data.optionsStageEditor.bfChar;
  }

  public var stageGirlfriendChar(get, set):String;

  function get_stageGirlfriendChar():String
  {
    if (data.optionsStageEditor.gfChar == null
      || CharacterDataParser.fetchCharacterData(data.optionsStageEditor.gfChar ?? "") == null) data.optionsStageEditor.gfChar = "gf";
    return data.optionsStageEditor.gfChar;
  }

  function set_stageGirlfriendChar(value:String):String
  {
    data.optionsStageEditor.gfChar = value;
    Save.system.flush();
    return data.optionsStageEditor.gfChar;
  }

  public var stageDadChar(get, set):String;

  function get_stageDadChar():String
  {
    if (data.optionsStageEditor.dadChar == null
      || CharacterDataParser.fetchCharacterData(data.optionsStageEditor.dadChar ?? "") == null) data.optionsStageEditor.dadChar = "dad";
    return data.optionsStageEditor.dadChar;
  }

  function set_stageDadChar(value:String):String
  {
    data.optionsStageEditor.dadChar = value;
    Save.system.flush();
    return data.optionsStageEditor.dadChar;
  }

  public function flush():Void
  {
    Save.system.flush();
  }

  public function addCharacterSeen(character:String):Void
  {
    if (data.unlocks.charactersSeen.contains(character)) return;

    data.unlocks.charactersSeen.push(character);
    Save.system.flush();
  }

  function getOrCreateLevel(levelId:String):SaveScoreDifficultiesData
  {
    var level = data.scores.levels.get(levelId);
    if (level == null)
    {
      level = [];
      data.scores.levels.set(levelId, level);
    }
    return level;
  }

  function getOrCreateSong(songId:String):SaveScoreDifficultiesData
  {
    var song = data.scores.songs.get(songId);
    if (song == null)
    {
      song = [];
      data.scores.songs.set(songId, song);
    }
    return song;
  }

  public function getLevelScore(levelId:String, difficultyId:String = 'normal'):Null<SaveScoreData>
  {
    if (data.scores == null)
    {
      data.scores = {
        songs: [],
        levels: []
      };
    }
    else if (data.scores.levels == null)
    {
      data.scores.levels = [];
    }

    return getOrCreateLevel(levelId).get(difficultyId);
  }

  public function setLevelScore(levelId:String, difficultyId:String, score:SaveScoreData):Void
  {
    getOrCreateLevel(levelId).set(difficultyId, score);
    Save.system.flush();
  }

  public function isLevelHighScore(levelId:String, difficultyId:String = 'normal', score:SaveScoreData):Bool
  {
    final currentScore:Null<SaveScoreData> = getOrCreateLevel(levelId).get(difficultyId);
    if (currentScore == null) return true;
    return score.score > currentScore.score;
  }

  public function hasBeatenLevel(levelId:String, ?difficultyList:Array<String>):Bool
  {
    #if UNLOCK_EVERYTHING
    return true;
    #else
    for (difficulty in (difficultyList ?? DEFAULT_DIFFICULTIES))
    {
      final score:Null<SaveScoreData> = getLevelScore(levelId, difficulty);
      if (score != null && score.score > 0) return true;
    }
    return false;
    #end
  }

  public function getSongScore(songId:String, difficultyId:String = 'normal', ?variation:String):Null<SaveScoreData>
  {
    final song:SaveScoreDifficultiesData = getOrCreateSong(songId);

    if (variation != null && variation != '' && variation != 'default' && variation != 'erect')
    {
      difficultyId = '${difficultyId}-${variation}';
    }

    return song.get(difficultyId);
  }

  public function getSongRank(songId:String, difficultyId:String = 'normal', ?variation:String):Null<ScoringRank>
  {
    return Scoring.calculateRank(getSongScore(songId, difficultyId, variation));
  }

  public function setSongScore(songId:String, difficultyId:String, score:SaveScoreData):Void
  {
    getOrCreateSong(songId).set(difficultyId, score);
    Save.system.flush();
  }

  public function applySongRank(songId:String, difficultyId:String, newScoreData:SaveScoreData):Void
  {
    if (newScoreData == null) return;

    final newRank = Scoring.calculateRank(newScoreData);
    if (newRank == null) return;

    final song:SaveScoreDifficultiesData = getOrCreateSong(songId);
    final previousScoreData = song.get(difficultyId);
    final previousRank = Scoring.calculateRank(previousScoreData);

    if (previousScoreData == null || previousRank == null)
    {
      setSongScore(songId, difficultyId, newScoreData);
      return;
    }

    final keepPreviousTallies:Bool = previousRank > newRank
      || Scoring.tallyCompletion(previousScoreData.tallies) > Scoring.tallyCompletion(newScoreData.tallies);

    song.set(difficultyId, {
      score: Std.int(Math.max(previousScoreData.score, newScoreData.score)),
      tallies: keepPreviousTallies ? previousScoreData.tallies : newScoreData.tallies
    });
    Save.system.flush();
  }

  public function isSongHighScore(songId:String, difficultyId:String = 'normal', score:SaveScoreData):Bool
  {
    final currentScore:Null<SaveScoreData> = getOrCreateSong(songId).get(difficultyId);
    if (currentScore == null) return true;
    return score.score > currentScore.score;
  }

  public function isSongHighRank(songId:String, difficultyId:String = 'normal', score:SaveScoreData):Bool
  {
    final newScoreRank = Scoring.calculateRank(score);
    if (newScoreRank == null) return false;

    final currentScoreRank = Scoring.calculateRank(getOrCreateSong(songId).get(difficultyId));
    if (currentScoreRank == null) return true;

    return newScoreRank > currentScoreRank;
  }

  public function hasBeatenSong(songId:String, ?difficultyList:Array<String>, ?variation:String):Bool
  {
    final suffix:String = (variation == null || variation == '') ? '' : '-${variation}';

    for (difficulty in (difficultyList ?? DEFAULT_DIFFICULTIES))
    {
      final score:Null<SaveScoreData> = getSongScore(songId, difficulty + suffix);
      if (score == null) continue;

      #if NO_UNLOCK_EVERYTHING
      if (score.score > 0) return true;
      #else
      return true;
      #end
    }
    return false;
  }

  public function isSongFavorited(id:String):Bool
  {
    if (data.favoriteSongs == null)
    {
      data.favoriteSongs = [];
      Save.system.flush();
    }
    return data.favoriteSongs.contains(id);
  }

  public function favoriteSong(id:String):Void
  {
    if (isSongFavorited(id)) return;

    data.favoriteSongs.push(id);
    Save.system.flush();
  }

  public function unfavoriteSong(id:String):Void
  {
    if (!isSongFavorited(id)) return;

    data.favoriteSongs.remove(id);
    Save.system.flush();
  }

  public function getControls(playerId:Int, inputType:Device):Null<SaveControlsData>
  {
    final player:Null<PlayerControlData> = (playerId == 0) ? data?.options?.controls?.p1 : data?.options?.controls?.p2;
    if (player == null) return null;

    return switch (inputType)
    {
      case Keys: player.keyboard;
      case Gamepad(_): player.gamepad;
    }
  }

  public function hasControls(playerId:Int, inputType:Device):Bool
  {
    final controls:Null<SaveControlsData> = getControls(playerId, inputType);
    if (controls == null) return false;
    return Reflect.fields(controls).length > 0;
  }

  public function setControls(playerId:Int, inputType:Device, controls:SaveControlsData):Void
  {
    final player:PlayerControlData = (playerId == 0) ? data.options.controls.p1 : data.options.controls.p2;

    switch (inputType)
    {
      case Keys:
        player.keyboard = controls;
      case Gamepad(_):
        player.gamepad = controls;
    }
  }

  public function isCharacterUnlocked(characterId:String):Bool
  {
    return switch (characterId)
    {
      case 'pico': hasBeatenLevel('weekend1');
      default: true;
    }
  }

  public function getModOptions(modId:String):Dynamic
  {
    if (!data.mods.modOptions.exists(modId))
    {
      data.mods.modOptions.set(modId, {});
    }

    return data.mods.modOptions.get(modId);
  }

  public function setModOptions(modId:String, options:Dynamic):Void
  {
    data.mods.modOptions.set(modId, options);
    Save.system.flush();
  }

  @:haxe.warning("-WDeprecated")
  static function loadFromSlot(slot:Int):Save
  {
    FlxG.save.bind(Constants.SAVE_NAME + slot, Constants.SAVE_PATH);

    switch (FlxG.save.status)
    {
      case EMPTY:
        final gameSave:Save = switch (Save.system.fetchLegacySaveData())
        {
          case None: new Save();
          case Some(legacySaveData): SaveDataMigrator.migrateFromLegacy(legacySaveData);
        }
        FlxG.save.mergeData(gameSave.data, true);
        return gameSave;
      case ERROR(_) | SAVE_ERROR(_) | LOAD_ERROR(_):
        return handleSaveDataError(slot);
      case BOUND(_, _):
        final gameSave:Save = SaveDataMigrator.migrate(FlxG.save.data);
        FlxG.save.mergeData(gameSave.data, true);
        return gameSave;
    }
  }

  static function handleSaveDataError(slot:Int):Save
  {
    final msg:String = 'There was an error loading your save data in slot ${slot}.\nPlease report this issue to the developers.';
    funkin.util.WindowUtil.showError("Save Data Failure", msg);

    final nextSlot:Int = slot + 1;
    if (nextSlot > 1000) throw "End of save data slots. Can't load any more.";
    return loadFromSlot(nextSlot);
  }

  public static function debug_queryBadSaveData():Void
  {
    final firstBadSaveData:Int = querySlotRange(1000, 1100);
    if (firstBadSaveData < 0) return;

    #if sys
    Sys.println('[SAVE] Found bad save data in slot ${firstBadSaveData}!');
    Sys.println(haxe.Json.stringify(fetchFromSlotRaw(firstBadSaveData)));
    #end
  }

  static function fetchFromSlotRaw(slot:Int):Null<Dynamic>
  {
    final targetSaveData:FlxSave = new FlxSave();
    targetSaveData.bind(Constants.SAVE_NAME + slot, Constants.SAVE_PATH);
    if (targetSaveData.isEmpty()) return null;
    return targetSaveData.data;
  }

  @:haxe.warning("-WDeprecated")
  static function querySlot(slot:Int):Bool
  {
    final targetSaveData:FlxSave = new FlxSave();
    targetSaveData.bind(Constants.SAVE_NAME + slot, Constants.SAVE_PATH);

    return switch (targetSaveData.status)
    {
      case BOUND(_, _): true;
      default: false;
    }
  }

  static function querySlotRange(start:Int, end:Int):Int
  {
    for (i in start...end)
    {
      if (querySlot(i)) return i;
    }
    return -1;
  }

  public function serializeJson(pretty:Bool = true):String
  {
    final writer = new json2object.JsonWriter<RawSaveData>(true);
    return writer.write(data, pretty ? ' ' : null);
  }

  public function updateVersionToLatest():Void
  {
    this.data.version = Save.SAVE_DATA_VERSION;
  }

  public function debug_dumpSaveJsonSave():Void
  {
    FileUtil.saveFile('Write save data as JSON...', haxe.io.Bytes.ofString(this.serializeJson()), [FileUtil.FILE_FILTER_JSON], null, null, './save.json');
  }

  public function debug_dumpSaveJsonPrint():Void
  {
    #if sys
    Sys.println(this.serializeJson());
    #end
  }

  #if FEATURE_NEWGROUNDS
  public static function saveToNewgrounds():Void
  {
    if (_instance == null) return;
    funkin.api.newgrounds.NGSaveSlot.instance.save(_instance.data);
  }

  public static function loadFromNewgrounds(onFinish:Void->Void):Void
  {
    funkin.api.newgrounds.NGSaveSlot.instance.load((data:Dynamic) ->
    {
      FlxG.save.bind(Constants.SAVE_NAME + Constants.BASE_SAVE_SLOT, Constants.SAVE_PATH);

      if (FlxG.save.status != EMPTY)
      {
        Save.system.archiveBadSaveData(FlxG.save.data);
      }

      FlxG.save.erase();
      FlxG.save.bind(Constants.SAVE_NAME + Constants.BASE_SAVE_SLOT, Constants.SAVE_PATH);

      final gameSave:Save = SaveDataMigrator.migrate(data);
      FlxG.save.mergeData(gameSave.data, true);
      _instance = gameSave;
      onFinish();
    }, (error:io.newgrounds.Call.CallError) ->
      {
        final errorMsg:String = io.newgrounds.Call.CallErrorTools.toString(error);
        final msg:String = 'There was an error loading your save data from Newgrounds.\n${errorMsg}\nAre you sure you are connected to the internet?';
        funkin.util.WindowUtil.showError("Newgrounds Save Slot Failure", msg);
      });
  }
  #end
}

typedef RawSaveData =
{
  var volume:Float;
  var mute:Bool;
  var version:Version;
  var api:SaveApiData;
  var scores:SaveHighScoresData;
  var options:SaveDataOptions;
  var unlocks:SaveDataUnlocks;
  #if mobile
  var mobileOptions:SaveDataMobileOptions;
  #end
  var favoriteSongs:Array<String>;
  var mods:SaveDataMods;
  var optionsChartEditor:SaveDataChartEditorOptions;
  var optionsStageEditor:SaveDataStageEditorOptions;
};

typedef SaveApiData =
{
  var newgrounds:SaveApiNewgroundsData;
}

typedef SaveApiNewgroundsData =
{
  var sessionId:Null<String>;
}

typedef SaveDataUnlocks =
{
  var charactersSeen:Array<String>;
  var oldChar:Bool;
}

typedef SaveHighScoresData =
{
  var levels:SaveScoreLevelsData;
  var songs:SaveScoreSongsData;
};

typedef SaveDataMods =
{
  var enabledMods:Array<String>;
  @:jignored
  var modOptions:Map<String, Dynamic>;
}

typedef SaveScoreLevelsData = Map<String, SaveScoreDifficultiesData>;

typedef SaveScoreSongsData = Map<String, SaveScoreDifficultiesData>;

typedef SaveScoreDifficultiesData = Map<String, SaveScoreData>;

typedef SaveScoreData =
{
  var score:Int;
  var tallies:SaveScoreTallyData;
}

typedef SaveScoreTallyData =
{
  var sick:Int;
  var good:Int;
  var bad:Int;
  var shit:Int;
  var missed:Int;
  var combo:Int;
  var maxCombo:Int;
  var totalNotesHit:Int;
  var totalNotes:Int;
}

typedef SaveDataOptions =
{
  var framerate:Int;
  var naughtyness:Bool;
  var downscroll:Bool;
  var flashingLights:Bool;
  var zoomCamera:Bool;
  var debugDisplay:String;
  var debugDisplayBGOpacity:Int;
  var subtitles:Bool;
  var hapticsMode:String;
  var hapticsIntensityMultiplier:Float;
  var autoPause:Bool;
  var vsyncMode:String;
  var strumlineBackgroundOpacity:Int;
  var autoFullscreen:Bool;
  var globalOffset:Int;
  var audioVisualOffset:Int;
  var unlockedFramerate:Bool;
  var enabledDiscordRPC:Bool;
  var screenshot:
    {
      var shouldHideMouse:Bool;
      var fancyPreview:Bool;
      var previewOnSave:Bool;
    };
  var controls:
    {
      var p1:PlayerControlData;
      var p2:PlayerControlData;
    };
}

typedef PlayerControlData =
{
  var keyboard:SaveControlsData;
  var gamepad:SaveControlsData;
}

#if mobile
typedef SaveDataMobileOptions =
{
  var screenTimeout:Bool;
  var controlsScheme:String;
  var noAds:Bool;
}
#end

typedef SaveControlsData =
{
  var ?UI_UP:Array<Int>;
  var ?UI_LEFT:Array<Int>;
  var ?UI_RIGHT:Array<Int>;
  var ?UI_DOWN:Array<Int>;
  var ?NOTE_LEFT:Array<Int>;
  var ?NOTE_UP:Array<Int>;
  var ?NOTE_DOWN:Array<Int>;
  var ?NOTE_RIGHT:Array<Int>;
  var ?ACCEPT:Array<Int>;
  var ?BACK:Array<Int>;
  var ?PAUSE:Array<Int>;
  var ?CUTSCENE_ADVANCE:Array<Int>;
  var ?VOLUME_UP:Array<Int>;
  var ?VOLUME_DOWN:Array<Int>;
  var ?VOLUME_MUTE:Array<Int>;
  var ?RESET:Array<Int>;
}

typedef SaveDataChartEditorOptions =
{
  var ?hasBackup:Bool;
  var ?previousFiles:Array<String>;
  var ?noteQuant:Int;
  var ?chartEditorLiveInputStyle:ChartEditorLiveInputStyle;
  var ?theme:ChartEditorTheme;
  var ?downscroll:Bool;
  var ?showNoteKinds:Bool;
  var ?showSubtitles:Bool;
  var ?metronomeVolume:Float;
  var ?hitsoundVolumePlayer:Float;
  var ?hitsoundVolumeOpponent:Float;
  var ?playtestStartTime:Bool;
  var ?playtestAudioSettings:Bool;
  var ?playtestResultsSettings:Bool;
  var ?themeMusic:Bool;
  var ?instVolume:Float;
  var ?playerVoiceVolume:Float;
  var ?opponentVoiceVolume:Float;
  var ?playbackSpeed:Float;
}

typedef SaveDataStageEditorOptions =
{
  var ?hasBackup:Bool;
  var ?previousFiles:Array<String>;
  var ?moveStep:String;
  var ?angleStep:Float;
  var ?theme:StageEditorTheme;
  var ?bfChar:String;
  var ?gfChar:String;
  var ?dadChar:String;
}
