package funkin.mobile.ui;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxSpriteGroup;
import flixel.input.actions.FlxActionInput;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSignal;
import funkin.data.notestyle.NoteStyleRegistry;
import funkin.graphics.FunkinSprite;
import funkin.graphics.shaders.HSVShader;
import funkin.mobile.input.ControlsHandler;
import funkin.play.notes.NoteDirection;
import funkin.play.notes.notestyle.NoteStyle;
import funkin.ui.FullScreenScaleMode;
import funkin.util.assets.FlxAnimationUtil;
import openfl.Vector;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.geom.Matrix;

enum FunkinHintAlphaStyle
{
  INVISIBLE_TILL_PRESS;
  VISIBLE_TILL_PRESS;
}

@:nullSafety
class FunkinHint extends FunkinButton
{
  static final HINT_ALPHA_STYLE:Map<FunkinHintAlphaStyle, Array<Float>> = [
    INVISIBLE_TILL_PRESS => [0.3, 0.00001, 0.01],
    VISIBLE_TILL_PRESS => [0.4, 0.2, 0.08]
  ];

  static final FOLLOW_WIDTH_MULTIPLIER:Float = 1.35;
  static final FOLLOW_HEIGHT_MULTIPLIER:Float = 8;

  public var isPixel:Bool = false;

  var noteDirection:NoteDirection;
  var label:Null<FunkinSprite>;
  var labelAlphaTween:Null<FlxTween>;
  var hsvShader:HSVShader;
  var alphaTween:Null<FlxTween>;
  var followTarget:Null<FunkinSprite>;
  var followTargetSize:Bool = false;

  public function new(x:Float, y:Float, noteDirection:NoteDirection, label:Null<FlxGraphic>):Void
  {
    super(x, y);

    this.noteDirection = noteDirection;

    if (label != null)
    {
      this.label = new FunkinSprite(x, y);
      this.label.loadGraphic(label);
    }

    hsvShader = new HSVShader();
    hsvShader.hue = 1.0;
    hsvShader.saturation = 1.0;
    hsvShader.value = 1.0;
    shader = hsvShader;
  }

  public function initTween(style:FunkinHintAlphaStyle):Void
  {
    final hintAlpha:Null<Array<Float>> = HINT_ALPHA_STYLE.get(style);

    if (hintAlpha == null || hintAlpha.length < 3) return;

    final swapValues:Bool = style == VISIBLE_TILL_PRESS;
    final pressedAlpha:Float = hintAlpha[swapValues ? 1 : 0];
    final releasedAlpha:Float = hintAlpha[swapValues ? 0 : 1];
    final duration:Float = hintAlpha[2];
    final alphaSum:Float = hintAlpha[0] + hintAlpha[1];

    function createTween(targetAlpha:Float):Void
    {
      alphaTween?.cancel();
      alphaTween = FlxTween.tween(this, {alpha: targetAlpha}, duration, {ease: FlxEase.circInOut});

      if (label != null)
      {
        labelAlphaTween?.cancel();
        labelAlphaTween = FlxTween.tween(label, {alpha: alphaSum - targetAlpha}, duration, {ease: FlxEase.circInOut});
      }
    }

    onDown.add(createTween.bind(pressedAlpha));
    onUp.add(createTween.bind(releasedAlpha));
    onOut.add(createTween.bind(releasedAlpha));

    alpha = releasedAlpha;

    if (label != null) label.alpha = hintAlpha[0];
  }

  public function follow(sprite:FunkinSprite, followTargetSize:Bool = true):Void
  {
    this.followTargetSize = followTargetSize;
    followTarget = sprite;
  }

  public function desaturate():Void
  {
    hsvShader.saturation = 0.2;
  }

  public function setHue(hue:Float):Void
  {
    hsvShader.hue = hue;
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    final target:Null<FunkinSprite> = followTarget;

    if (target == null) return;

    final xOffset:Float = isPixel ? 43.265 : 0;
    final yOffset:Float = isPixel ? 57.65 : 0;

    if (followTargetSize)
    {
      setSize(target.width * FOLLOW_WIDTH_MULTIPLIER + (isPixel ? 93.05 : 0), target.height * FOLLOW_HEIGHT_MULTIPLIER + (isPixel ? 118 : 0));
    }

    setPosition((target.x - (target.width * ((FOLLOW_WIDTH_MULTIPLIER - 1) / 2))) - xOffset, (target.y - 220) - yOffset);
  }

  override public function draw():Void
  {
    super.draw();

    if (label != null && label.visible)
    {
      label.cameras = _cameras;
      label.draw();
    }
  }

  #if FLX_DEBUG
  override public function drawDebug():Void
  {
    super.drawDebug();

    if (label != null) label.drawDebug();
  }
  #end

  override public function destroy():Void
  {
    if (alphaTween != null) alphaTween = FlxDestroyUtil.destroy(alphaTween);

    if (labelAlphaTween != null) labelAlphaTween = FlxDestroyUtil.destroy(labelAlphaTween);

    if (label != null) label = FlxDestroyUtil.destroy(label);

    super.destroy();
  }

  override function set_x(v:Float):Float
  {
    super.set_x(v);

    if (label != null) label.x = x;

    return x;
  }

  override function set_y(v:Float):Float
  {
    super.set_y(v);

    if (label != null) label.y = y;

    return y;
  }
}

enum abstract FunkinHitboxControlSchemes(String) from String to String
{
  public var FourLanes = 'Four Lanes';
  public var DoubleThumbTriangle = 'Double Thumb Triangle';
  public var DoubleThumbSquare = 'Double Thumb Square';
  public var DoubleThumbDPad = 'Double Thumb DPad';
  public var Arrows = 'Arrows';

  public static final DEFAULT:FunkinHitboxControlSchemes = FourLanes;

  public static final ALL:Array<FunkinHitboxControlSchemes> = [FourLanes, DoubleThumbTriangle, DoubleThumbSquare, DoubleThumbDPad, Arrows];

  public static function resolve(?scheme:String):FunkinHitboxControlSchemes
  {
    if (scheme == null || scheme.length == 0) return DEFAULT;

    for (validScheme in ALL)
    {
      if ((validScheme : String) == scheme) return validScheme;
    }

    return DEFAULT;
  }
}

@:nullSafety
class FunkinHitbox extends FlxTypedSpriteGroup<FunkinHint>
{
  static final DEFAULT_COLORS:Array<FlxColor> = [0xFFC34B9A, 0xFF00FFFF, 0xFF12FB06, 0xFFF9393F];
  static final DEFAULT_DIRECTIONS:Array<NoteDirection> = [NoteDirection.LEFT, NoteDirection.DOWN, NoteDirection.UP, NoteDirection.RIGHT];

  public var isPixel(default, set):Bool = false;

  public var onHintDown:FlxTypedSignal<FunkinHint->Void> = new FlxTypedSignal<FunkinHint->Void>();
  public var onHintUp:FlxTypedSignal<FunkinHint->Void> = new FlxTypedSignal<FunkinHint->Void>();

  var trackedInputs:Array<FlxActionInput> = [];

  public function new(?schemeOverride:String, ?showGradint:Bool = true, ?directionsOverride:Array<NoteDirection>, ?colorsOverride:Array<FlxColor>):Void
  {
    super();

    final hintsColors:Array<FlxColor> = (colorsOverride == null || colorsOverride.length == 0) ? DEFAULT_COLORS : colorsOverride;
    final hintsNoteDirections:Array<NoteDirection> = (directionsOverride == null || directionsOverride.length == 0) ? DEFAULT_DIRECTIONS : directionsOverride;
    final gradient:Bool = showGradint ?? true;

    #if mobile
    final controlsScheme:FunkinHitboxControlSchemes = FunkinHitboxControlSchemes.resolve((schemeOverride == null
      || schemeOverride.length == 0) ? Preferences.controlsScheme : schemeOverride);

    switch (controlsScheme)
    {
      case FunkinHitboxControlSchemes.FourLanes:
        buildFourLanes(hintsNoteDirections, hintsColors, gradient);
      case FunkinHitboxControlSchemes.DoubleThumbTriangle:
        buildDoubleThumbTriangle(hintsNoteDirections, hintsColors, gradient);
      case FunkinHitboxControlSchemes.DoubleThumbSquare:
        buildDoubleThumbSquare(hintsNoteDirections, hintsColors, gradient);
      case FunkinHitboxControlSchemes.DoubleThumbDPad:
        buildDoubleThumbDPad(hintsNoteDirections, hintsColors);
      case FunkinHitboxControlSchemes.Arrows:
        buildArrows(hintsNoteDirections);
      default:
        buildFourLanes(hintsNoteDirections, hintsColors, gradient);
    }
    #end

    scrollFactor.set();

    ControlsHandler.setupHitbox(PlayerSettings.player1.controls, this, trackedInputs);
  }

  function buildFourLanes(directions:Array<NoteDirection>, colors:Array<FlxColor>, gradient:Bool):Void
  {
    final hintWidth:Int = Math.floor(FlxG.width / directions.length);
    final hintHeight:Int = FlxG.height;

    for (i in 0...directions.length)
    {
      add(createHintLane(i * hintWidth, 0, directions[i], hintWidth, hintHeight, colors[i % colors.length], true, gradient));
    }
  }

  function buildDoubleThumbTriangle(directions:Array<NoteDirection>, colors:Array<FlxColor>, gradient:Bool):Void
  {
    final screenHalf:Int = Math.floor(FlxG.width / 2);
    final quarterWidth:Int = Math.floor(FlxG.width / 4);
    final halfHeight:Int = Math.floor(FlxG.height / 2);

    for (i in 0...2)
    {
      final xOffset:Int = (i == 1) ? screenHalf : 0;

      add(createHintTriangle(xOffset, 0, directions[0], quarterWidth, FlxG.height, colors[0], gradient));
      add(createHintTriangle(xOffset, halfHeight, directions[1], screenHalf, halfHeight, colors[1], gradient));
      add(createHintTriangle(xOffset, 0, directions[2], screenHalf, halfHeight, colors[2], gradient));
      add(createHintTriangle(xOffset + quarterWidth, 0, directions[3], quarterWidth, FlxG.height, colors[3], gradient));
    }
  }

  function buildDoubleThumbSquare(directions:Array<NoteDirection>, colors:Array<FlxColor>, gradient:Bool):Void
  {
    final screenHalf:Int = Math.floor(FlxG.width / 2);
    final hintWidth:Int = Math.floor((FlxG.width / directions.length) / 2);
    final hintHeight:Int = FlxG.height;
    final boxWidth:Int = hintWidth * 2;
    final boxHeight:Int = Math.floor(hintHeight / 2);

    for (i in 0...2)
    {
      final xOffset:Int = (i == 1) ? screenHalf : 0;

      for (j in 0...directions.length)
      {
        final color:FlxColor = colors[j % colors.length];

        if (j == 1 || j == 2)
        {
          add(createHintLane(xOffset + hintWidth, (j == 1) ? boxHeight : 0, directions[j], boxWidth, boxHeight, color, false, gradient));
        }
        else
        {
          add(createHintLane(xOffset + (j == 0 ? 0 : hintWidth + boxWidth), 0, directions[j], hintWidth, hintHeight, color, false, gradient));
        }
      }
    }
  }

  function buildDoubleThumbDPad(directions:Array<NoteDirection>, colors:Array<FlxColor>):Void
  {
    final hintSize:Int = 75;
    final outlineThickness:Int = 5;
    final hintsAngles:Array<Float> = [Math.PI, Math.PI / 2, Math.PI * 1.5, 0];
    final hintsZoneRadius:Int = 115;

    for (i in 0...2)
    {
      for (j in 0...hintsAngles.length)
      {
        final x:Float = ((i == 1) ? FlxG.width - (hintSize * 4) : hintSize * 2) + Math.cos(hintsAngles[j]) * hintsZoneRadius;
        final y:Float = (FlxG.height - (hintSize * 3.75)) + Math.sin(hintsAngles[j]) * hintsZoneRadius;
        final notchX:Float = FullScreenScaleMode.gameNotchSize.x;

        add(createHintCircle(i == 0 ? x + notchX : x - notchX, y, directions[j % directions.length], hintSize, outlineThickness,
          colors[j % colors.length]));
      }
    }
  }

  function buildArrows(directions:Array<NoteDirection>):Void
  {
    final hintWidth:Int = 146;
    final hintHeight:Int = 149;
    final noteSpacing:Int = 80;

    final xPos:Int = Math.floor((FlxG.width - (hintWidth + noteSpacing) * directions.length) / 2);
    final yPos:Int = Math.floor(FlxG.height - hintHeight * 2 - 24);

    for (i in 0...directions.length)
    {
      add(createHintTransparentNote(xPos + i * (hintWidth + noteSpacing), yPos, directions[i], hintWidth, hintHeight));
    }
  }

  public function getFirstHintByDirection(direction:NoteDirection):Null<FunkinHint>
  {
    var result:Null<FunkinHint> = null;

    forEachOfType(FunkinHint, function(hint:FunkinHint):Void
    {
      @:privateAccess
      if (hint.noteDirection == direction) result = hint;
    });

    return result;
  }

  function bindHintSignals(hint:FunkinHint):Void
  {
    hint.onDown.add(onHintDown.dispatch.bind(hint));
    hint.onUp.add(onHintUp.dispatch.bind(hint));
    hint.onOut.add(onHintUp.dispatch.bind(hint));
  }

  function createHintLane(x:Float, y:Float, noteDirection:NoteDirection, width:Int, height:Int, color:FlxColor = 0xFFFFFFFF, label:Bool = true,
      gradient:Bool = true):FunkinHint
  {
    final hint:FunkinHint = new FunkinHint(x, y, noteDirection, label ? createHintLaneLabelGraphic(width, height, Math.floor(height * 0.035), color) : null);
    hint.loadGraphic(createHintLaneGraphic(width, height, color, gradient));
    bindHintSignals(hint);
    hint.initTween(INVISIBLE_TILL_PRESS);
    return hint;
  }

  function createHintTriangle(x:Float, y:Float, noteDirection:NoteDirection, width:Int, height:Int, color:FlxColor = 0xFFFFFFFF,
      gradient:Bool = true):FunkinHint
  {
    final hint:FunkinHint = new FunkinHint(x, y, noteDirection, null);
    hint.loadGraphic(createHintTriangleGraphic(width, height, noteDirection, color, gradient));
    bindHintSignals(hint);
    hint.initTween(INVISIBLE_TILL_PRESS);
    hint.polygon = getTriangleVertices(width, height, noteDirection);
    return hint;
  }

  function createHintCircle(x:Float, y:Float, noteDirection:NoteDirection, radius:Float, outlineThickness:Int, color:FlxColor = 0xFFFFFFFF):FunkinHint
  {
    final hint:FunkinHint = new FunkinHint(x, y, noteDirection, null);
    hint.loadGraphic(createHintCircleGraphic(radius, outlineThickness, color));
    hint.limitToBounds = false;
    hint.radius = radius;
    bindHintSignals(hint);
    hint.initTween(VISIBLE_TILL_PRESS);
    return hint;
  }

  function createHintTransparentNote(x:Float, y:Float, noteDirection:NoteDirection, width:Int, height:Int):FunkinHint
  {
    final hint:FunkinHint = new FunkinHint(x, y, noteDirection, null);
    hint.alpha = 0;
    hint.setSize(width, height);
    bindHintSignals(hint);

    final noteStyle:NoteStyle = NoteStyleRegistry.instance.fetchDefault();

    @:privateAccess
    @:nullSafety(Off)
    {
      hint.frames = Paths.getSparrowAtlas(noteStyle.getStrumlineAssetPath() ?? '', noteStyle.getAssetLibrary(noteStyle.getStrumlineAssetPath(true)));
      FlxAnimationUtil.addAtlasAnimations(hint, noteStyle.getStrumlineAnimationData(noteDirection));
    }

    function playAnimation(name:String):Void
    {
      hint.animation.play(name, true);
      hint.centerOrigin();
      hint.centerOffsets();
    }

    hint.onDown.add(playAnimation.bind('press'));
    hint.onUp.add(playAnimation.bind('static'));
    hint.onOut.add(playAnimation.bind('static'));

    playAnimation('static');

    return hint;
  }

  function createHintLaneGraphic(width:Int, height:Int, baseColor:FlxColor = 0xFFFFFFFF, gradient:Bool = true):FlxGraphic
  {
    final shape:Shape = new Shape();

    beginHintFill(shape, width, height, baseColor, gradient);
    shape.graphics.drawRect(0, 0, width, height);
    shape.graphics.endFill();

    return shapeToGraphic(shape, width, height);
  }

  function createHintLaneLabelGraphic(width:Int, height:Int, labelHeight:Int, baseColor:FlxColor = 0xFFFFFFFF):FlxGraphic
  {
    final shape:Shape = new Shape();

    final topMatrix:Matrix = new Matrix();
    topMatrix.createGradientBox(width, labelHeight, Math.PI / 2, 0, 0);
    shape.graphics.beginGradientFill(LINEAR, [baseColor.rgb, baseColor.rgb], [baseColor.alphaFloat, 0], [0, 255], topMatrix);
    shape.graphics.drawRect(0, 0, width, labelHeight);
    shape.graphics.endFill();

    final bottomMatrix:Matrix = new Matrix();
    bottomMatrix.createGradientBox(width, labelHeight, Math.PI / 2, 0, height - labelHeight);
    shape.graphics.beginGradientFill(LINEAR, [baseColor.rgb, baseColor.rgb], [0, baseColor.alphaFloat], [0, 255], bottomMatrix);
    shape.graphics.drawRect(0, height - labelHeight, width, labelHeight);
    shape.graphics.endFill();

    return shapeToGraphic(shape, width, height);
  }

  function createHintTriangleGraphic(width:Int, height:Int, facing:NoteDirection, baseColor:FlxColor = 0xFFFFFFFF, gradient:Bool = true):FlxGraphic
  {
    final shape:Shape = new Shape();

    beginHintFill(shape, width, height, baseColor, gradient);
    shape.graphics.drawRect(width / 2, height / 2, width / 2, height / 2);
    shape.graphics.drawTriangles(Vector.ofArray(getTriangleVertices(width, height, facing)), Vector.ofArray([0, 1, 2]));
    shape.graphics.endFill();

    return shapeToGraphic(shape, width, height);
  }

  function createHintCircleGraphic(radius:Float, outlineThickness:Int, baseColor:FlxColor = 0xFFFFFFFF):FlxGraphic
  {
    var fillColor:FlxColor = baseColor;
    var brightColor:FlxColor = baseColor;
    brightColor.brightness += 0.6;

    if (fillColor.brightness >= 0.75) fillColor.alphaFloat -= fillColor.brightness * 0.35;

    final shape:Shape = new Shape();
    shape.graphics.beginFill(fillColor.rgb, fillColor.alphaFloat);
    shape.graphics.lineStyle(outlineThickness, brightColor.rgb, brightColor.alphaFloat);
    shape.graphics.drawCircle(radius, radius, radius);
    shape.graphics.endFill();

    final matrix:Matrix = new Matrix();
    matrix.translate(outlineThickness, outlineThickness);

    final size:Int = Math.floor((radius + outlineThickness) * 2);
    final graphicData:BitmapData = new BitmapData(size, size, true, 0);
    graphicData.draw(shape, matrix, true);
    return FlxGraphic.fromBitmapData(graphicData, false, null, false);
  }

  function beginHintFill(shape:Shape, width:Int, height:Int, baseColor:FlxColor, gradient:Bool):Void
  {
    if (gradient)
    {
      final matrix:Matrix = new Matrix();
      matrix.createGradientBox(width, height, 0, 0, 0);
      shape.graphics.beginGradientFill(RADIAL, [baseColor.rgb, baseColor.rgb], [0, baseColor.alphaFloat], [60, 255], matrix, PAD, RGB, 0);
    }
    else
    {
      shape.graphics.beginFill(baseColor.rgb, baseColor.alphaFloat);
    }
  }

  function shapeToGraphic(shape:Shape, width:Int, height:Int):FlxGraphic
  {
    final graphicData:BitmapData = new BitmapData(width, height, true, 0);
    graphicData.draw(shape, true);
    return FlxGraphic.fromBitmapData(graphicData, false, null, false);
  }

  function getTriangleVertices(width:Int, height:Int, facing:NoteDirection):Array<Float>
  {
    return switch (facing)
    {
      case DOWN: [width / 2, 0, 0, height, width, height];
      case UP: [0, 0, width, 0, width / 2, height];
      case LEFT: [0, 0, width, height / 2, 0, height];
      case RIGHT: [width, 0, 0, height / 2, width, height];
    }
  }

  override public function destroy():Void
  {
    if (trackedInputs != null && trackedInputs.length > 0) ControlsHandler.removeCachedInput(PlayerSettings.player1.controls, trackedInputs);

    FlxDestroyUtil.destroy(onHintDown);
    FlxDestroyUtil.destroy(onHintUp);

    super.destroy();
  }

  @:noCompletion
  function set_isPixel(value:Bool):Bool
  {
    isPixel = value;

    forEachOfType(FunkinHint, function(hint:FunkinHint):Void
    {
      hint.isPixel = value;
    });

    return value;
  }
}
