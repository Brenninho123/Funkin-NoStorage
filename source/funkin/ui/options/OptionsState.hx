package funkin.ui.options;

import flixel.FlxObject;
import flixel.FlxSprite;
import funkin.audio.FunkinSound;
import funkin.graphics.shaders.HSVShader;
import funkin.ui.MusicBeatState;
import funkin.ui.Page.PageName;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import funkin.ui.mainmenu.MainMenuState;
#if FEATURE_NEWGROUNDS
import funkin.api.newgrounds.NewgroundsClient;
#end
#if mobile
import funkin.mobile.input.ControlsHandler;
import funkin.mobile.ui.FunkinBackButton;
#end
#if FEATURE_MOBILE_IAP
import funkin.mobile.util.InAppPurchasesUtil;
#end

class OptionsState extends MusicBeatState
{
  public static var instance:OptionsState;

  public static var rememberedSelectedIndex:Int = 0;

  public var drumsBG:FunkinSound;

  var optionsCodex:Codex<OptionsMenuPageName>;

  override function create():Void
  {
    instance = this;

    persistentUpdate = true;

    drumsBG = FunkinSound.load(Paths.music('offsetsLoop/drumsLoop'), 0, true, false, false, false);

    var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuBG'));
    menuBG.shader = new HSVShader(-0.6, 0.9, 3.6);
    menuBG.setGraphicSize(Std.int(FlxG.width * 1.1));
    menuBG.updateHitbox();
    menuBG.screenCenter();
    menuBG.scrollFactor.set(0, 0);
    add(menuBG);

    optionsCodex = new Codex<OptionsMenuPageName>(Options);
    add(optionsCodex);

    var options:OptionsMenu = optionsCodex.addPage(Options, new OptionsMenu());
    var preferences:PreferencesMenu = optionsCodex.addPage(Preferences, new PreferencesMenu());
    var controls:ControlsMenu = optionsCodex.addPage(Controls, new ControlsMenu());
    #if FEATURE_LAG_ADJUSTMENT
    var offsets:OffsetMenu = optionsCodex.addPage(Offsets, new OffsetMenu());
    #end
    var saveData:SaveDataMenu = optionsCodex.addPage(SaveData, new SaveDataMenu());

    options.addSaveDataOptionsItem(saveData);
    options.addExitItem();

    if (options.hasMultipleOptions())
    {
      options.onExit.add(exitToMainMenu);
      controls.onExit.add(exitControls);
      preferences.onExit.add(optionsCodex.switchPage.bind(Options));
      #if FEATURE_LAG_ADJUSTMENT
      offsets.onExit.add(exitOffsets);
      #end
      saveData.onExit.add(optionsCodex.switchPage.bind(Options));
    }
    else
    {
      #if mobile
      preferences.onExit.add(exitToMainMenu);
      optionsCodex.setPage(Preferences);
      #else
      controls.onExit.add(exitToMainMenu);
      optionsCodex.setPage(Controls);
      #end
    }

    super.create();

    #if mobile
    addHitbox();
    hitbox.visible = false;
    #end
  }

  function exitOffsets():Void
  {
    if (drumsBG.volume > 0)
    {
      drumsBG.fadeOut(0.5, 0);
    }

    FlxG.sound.music.fadeOut(0.5, 0, function(_)
    {
      FunkinSound.playMusic('freakyMenu', {
        startingVolume: 0,
        overrideExisting: true,
        restartTrack: true,
        persist: true
      });
      FlxG.sound.music.fadeIn(0.5, 1);
    });

    optionsCodex.switchPage(Options);
  }

  function exitControls():Void
  {
    PlayerSettings.reset();
    PlayerSettings.init();

    optionsCodex.switchPage(Options);
  }

  function exitToMainMenu():Void
  {
    optionsCodex.currentPage.enabled = false;
    FlxG.keys.enabled = false;
    FlxG.switchState(() -> new MainMenuState());
  }
}

class OptionsMenu extends Page<OptionsMenuPageName>
{
  static final CAMERA_MARGIN:Int = 150;

  var items:TextMenuList;
  var camFocusPoint:FlxObject;

  #if FEATURE_TOUCH_CONTROLS
  var backButton:FunkinBackButton;
  var goingBack:Bool = false;
  #end

  public function new()
  {
    super();

    add(items = new TextMenuList());

    createItem('PREFERENCES', function() codex.switchPage(Preferences));

    #if mobile
    if (ControlsHandler.hasExternalInputDevice)
    #end
    createItem('CONTROLS', function() codex.switchPage(Controls));

    #if FEATURE_LAG_ADJUSTMENT
    createItem('LAG ADJUSTMENT', openOffsets);
    #end

    #if FEATURE_MOBILE_IAP
    createItem('RESTORE PURCHASES', function() InAppPurchasesUtil.restorePurchases());
    #end

    #if FEATURE_NEWGROUNDS
    addNewgroundsItem();
    #end

    camFocusPoint = new FlxObject(0, 0, 140, 70);
    add(camFocusPoint);

    FlxG.camera.follow(camFocusPoint, null, 0.085);
    FlxG.camera.deadzone.set(0, CAMERA_MARGIN / 2, FlxG.camera.width, FlxG.camera.height - CAMERA_MARGIN + 40);
    FlxG.camera.minScrollY = -CAMERA_MARGIN / 2;

    items.onChange.add(onMenuChange);

    onMenuChange(items.members[0]);

    items.selectItem(OptionsState.rememberedSelectedIndex);

    #if FEATURE_TOUCH_CONTROLS
    FlxG.touches.swipeThreshold.y = 100;
    #end
  }

  #if FEATURE_LAG_ADJUSTMENT
  function openOffsets():Void
  {
    var switchToOffsets:Void->Void = function()
    {
      FunkinSound.playMusic('offsetsLoop', {
        startingVolume: 0,
        overrideExisting: true,
        restartTrack: true,
        loop: true
      });
      OptionsState.instance.drumsBG.play(true);
      FlxG.sound.music.fadeIn(1, 1);
      codex.switchPage(Offsets);
    };

    if (FlxG.sound.music != null)
    {
      FlxG.sound.music.fadeOut(0.5, 0, function(_) switchToOffsets());
    }
    else
    {
      switchToOffsets();
    }
  }
  #end

  #if FEATURE_NEWGROUNDS
  function addNewgroundsItem():Void
  {
    if (NewgroundsClient.instance.isLoggedIn())
    {
      createItem('LOGOUT OF NG', function()
      {
        NewgroundsClient.instance.logout(function() FlxG.resetState(), function() FlxG.log.warn('Newgrounds logout failed!'));
      });
    }
    else
    {
      createItem('LOGIN TO NG', function()
      {
        NewgroundsClient.instance.login(function() FlxG.resetState(), function() FlxG.log.warn('Newgrounds login failed!'));
      });
    }
  }
  #end

  public function addSaveDataOptionsItem(saveDataMenu:SaveDataMenu):Void
  {
    if (saveDataMenu.hasMultipleOptions())
    {
      createItem('SAVE DATA OPTIONS', function() codex.switchPage(SaveData));
    }
    else
    {
      createItem('CLEAR SAVE DATA', saveDataMenu.openSaveDataPrompt);
    }
  }

  public function addExitItem():Void
  {
    #if FEATURE_TOUCH_CONTROLS
    backButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, exit, 1.0);
    backButton.onConfirmStart.add(function()
    {
      items.busy = true;
      goingBack = true;
      backButton.active = true;
    });
    add(backButton);
    #else
    createItem('EXIT', exit);
    #end
  }

  function onMenuChange(selected:TextMenuItem):Void
  {
    camFocusPoint.y = selected.y;
  }

  function createItem(name:String, callback:Void->Void, fireInstantly:Bool = false):TextMenuItem
  {
    var item:TextMenuItem = items.createItem(0, 100 + items.length * 100, name, BOLD, callback);
    item.fireInstantly = fireInstantly;
    item.screenCenter(X);
    return item;
  }

  override function update(elapsed:Float):Void
  {
    if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.8)
    {
      FlxG.sound.music.volume += 0.5 * elapsed;
    }

    #if FEATURE_TOUCH_CONTROLS
    backButton.active = goingBack || !items.busy;
    #end

    super.update(elapsed);
  }

  override function set_enabled(value:Bool):Bool
  {
    items.enabled = value;
    return super.set_enabled(value);
  }

  public function hasMultipleOptions():Bool
  {
    return items.length > 2;
  }
}

enum abstract OptionsMenuPageName(String) to PageName
{
  public var Options = 'options';
  public var Controls = 'controls';
  public var Colors = 'colors';
  public var Mods = 'mods';
  public var Preferences = 'preferences';
  public var Offsets = 'offsets';
  public var SaveData = 'saveData';
}
