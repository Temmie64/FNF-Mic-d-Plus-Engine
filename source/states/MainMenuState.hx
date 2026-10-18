package states;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import states.editors.MasterEditorMenu;
import options.OptionsState;
import flixel.text.FlxText;
import openfl.display.BitmapData;
import flixel.FlxCamera;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.addons.display.FlxBackdrop;
import flixel.util.FlxGradient;
import flixel.util.FlxAxes;
#if mobile
import mobile.backend.MobileScaleMode;
#end

enum MainMenuColumn
{
	LEFT;
	CENTER;
	RIGHT;
}

class MainMenuState extends MusicBeatState
{
	public static var fnfVersion:String = '0.2.8';
	public static var plusEngineVersion:String = '1.3'; // Nothing interesting =)
	public static var micUP:String = '2.0.3'; // Mic'd Up Engine version
	public static var isOpt(get, never):String;
	public static var psychEngineVersion(get, never):String; // This is also used for Discord RPC
	public static var curSelected:Int = 0;
	public static var curColumn:MainMenuColumn = MainMenuColumn.CENTER;
	private var camGame:FlxCamera;

	static function get_isOpt():String
	#if OPT_VER
		return "Optimized";
	#else
	    return "";
	#end

	static function get_psychEngineVersion():String
	{
		var suffix:String = isOpt;
		return "1.0.4 (" + plusEngineVersion + ")" + (suffix.length > 0 ? " " + suffix : "");
	}

	public var allowMouse:Bool = true; // Turn this off to block mouse movement in menus

	public var menuItems:PlusMainMenuItemGroup;
	public var leftWatermarkText:FlxText;
	public var leftItem:FlxSprite;
	public var rightItem:FlxSprite;

	inline function safeX(x:Float):Float
	{
		#if mobile
		return MobileScaleMode.getHorizontalOffset() + x;
		#else
		return x;
		#end
	}

	inline function safeWidth():Float
	{
		#if mobile
		return MobileScaleMode.getSafeWidth();
		#else
		return FlxG.width;
		#end
	}

	// Centered/Text options
	public var optionShit:Array<String> = ['play', #if MODS_ALLOWED 'mods', #end 'credits', 'options'];

	public var leftOption:String = #if ACHIEVEMENTS_ALLOWED 'achievements' #else null #end;
	public var rightOption:String = null;

	var magenta:FlxSprite;
	var bg:FlxSprite;
	var side:FlxSprite;
	var camFollow:FlxObject;

	//var checker:FlxBackdrop = new FlxBackdrop(Paths.image('MicUp/Main_Checker'), 0.2, 0.2, true, true);
	var checker:FlxBackdrop = new FlxBackdrop(Paths.image('MicUp/Main_Checker'), flixel.util.FlxAxes.XY);
	var gradientBar:FlxSprite = FlxGradient.createGradientFlxSprite(Math.round(FlxG.width),512, [0x00FF0000, 0x55AE59E4, 0xAA19ECFF], 1, 90, true);
	var camLerp:Float = 0.1;

	static var showOutdatedWarning:Bool = true;
	static var updateWarningShown:Bool = false;

	override function create()
	{
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence(Language.getPhrase('states.main_menu.presence', 'In the Menus'), null);
		#end

		//transIn = FlxTransitionableState.defaultTransIn;
		//transOut = FlxTransitionableState.defaultTransOut;

		camGame = new FlxCamera();
		FlxG.cameras.reset(camGame);

		persistentUpdate = persistentDraw = true;

		var yScroll:Float = Math.max(0.25 - (0.05 * (optionShit.length - 4)), 0.1);
		/*var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);*/

		bg = new FlxSprite(-89).loadGraphic(Paths.image('MicUp/mBG_Main'));
		bg.scrollFactor.x = 0;
		bg.scrollFactor.y = 0.16;
		bg.setGraphicSize(Std.int(bg.width * 1.125));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = true;
		bg.angle = 179;
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		//gradientBar = FlxGradient.createGradientFlxSprite(Math.round(FlxG.width), 512, [0x00ff0000, 0x55AE59E4, 0xAA19ECFF], 1, 90, true);
		gradientBar.y = FlxG.height - gradientBar.height;
		add(gradientBar);
		gradientBar.scrollFactor.set(0, 0);

		add(checker);
		checker.scrollFactor.set(0, 0.07);

		side = new FlxSprite(0).loadGraphic(Paths.image('MicUp/Main_Side'));
		side.scrollFactor.x = 0;
		side.scrollFactor.y = 0;
		side.x += -20;
		side.antialiasing = true;
		side.alpha = 0;
		add(side);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);

		menuItems = new PlusMainMenuItemGroup();
		add(menuItems);

		var offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
		for (num => option in optionShit)
		{
			var item:FlxSprite = createMenuItem(option, 0, 40 + (num * 200) + offset);
			item.x = item.width / 4 + (num * 180) - 30;
			var scroll:Float = optionShit.length < 6 ? 0 : (optionShit.length - 4) * 0.135;
			item.scrollFactor.set(0, scroll);
			tweenMenuItemIn(item);
		}

		if (leftOption != null)
		{
			leftItem = createMenuItem(leftOption, safeX(60), 490);
			tweenMenuItemIn(leftItem);
		}
		if (rightOption != null)
		{
			rightItem = createMenuItem(rightOption, safeX(safeWidth() - 60), 490);
			rightItem.x -= rightItem.width;
			tweenMenuItemIn(rightItem);
		}

		var buildLine:String = BuildInfo.versionLine();
		var hasBuildLine:Bool = buildLine.length > 0;

		var micUpVer:FlxText = new FlxText(safeX(12), FlxG.height - (hasBuildLine ? 80 : 64), 0,
			Language.getPhrase('states.main_menu.version.mic_engine', "Mic'd Up v{1}", [micUP]), 12);
		micUpVer.scrollFactor.set();
		micUpVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(micUpVer);

		var psychVer:FlxText = new FlxText(safeX(12), FlxG.height - (hasBuildLine ? 64 : 44), 0,
			Language.getPhrase('states.main_menu.version.psych_engine', 'Psych Engine v{1}', [psychEngineVersion]), 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);
		var fnfVer:FlxText = new FlxText(safeX(12), FlxG.height - (hasBuildLine ? 44 : 24), 0,
			Language.getPhrase('states.main_menu.version.friday_night_funkin', "Friday Night Funkin' v{1}", [fnfVersion]), 12);
		fnfVer.scrollFactor.set();
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		leftWatermarkText = fnfVer;
		add(fnfVer);
		if (hasBuildLine)
		{
			var buildVer:FlxText = new FlxText(safeX(12), FlxG.height - 24, 0, buildLine, 12);
			buildVer.scrollFactor.set();
			buildVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(buildVer);
		}
		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		// Unlocks "Freaky on a Friday Night" achievement if it's a Friday and between 18:00 PM and 23:59 PM
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		#if CHECK_FOR_UPDATES
		tryShowOutdatedWarning();
		#end
		#if MODS_ALLOWED
		tryShowModSecurityWarning();
		#end

		FlxG.camera.follow(camFollow, null, camLerp);
		FlxG.camera.zoom = 3;
		FlxTween.tween(FlxG.camera, {zoom: 1}, 1.4, {ease: FlxEase.expoInOut});
		FlxTween.tween(bg, {angle: 0}, 1.2, {ease: FlxEase.quartInOut});
		FlxTween.tween(side, {alpha: 1}, 1, {ease: FlxEase.quartInOut});

		addTouchPad('NONE', 'E_X');

	}

	#if MODS_ALLOWED
	function tryShowModSecurityWarning():Void
	{
		if (selectedSomethin || subState != null)
			return;

		var pending:Array<String> = backend.SecurityReview.getPendingMods();
		if (pending.length < 1)
			return;

		persistentUpdate = false;
		openSubState(backend.SecurityReview.createPrompt(pending));
	}
	#end

	#if CHECK_FOR_UPDATES
	function tryShowOutdatedWarning():Void
	{
		if (!showOutdatedWarning || !ClientPrefs.data.checkForUpdates || updateWarningShown || selectedSomethin)
			return;

		if (CoolUtil.hasUpdate && CoolUtil.latestVersion != plusEngineVersion)
		{
			substates.OutdatedSubState.updateVersion = CoolUtil.latestVersion;
			persistentUpdate = false;
			updateWarningShown = true;
			openSubState(backend.ScriptableSubstate.tryCreate('OutdatedSubState', new substates.OutdatedSubState()));
		}
	}
	#end

	function createMenuItem(name:String, x:Float, y:Float):FlxSprite
	{
		var menuItem:FlxSprite = new FlxSprite(x, y);
		try
		{
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_$name');
		}
		catch (e:Dynamic)
		{
			trace('Main menu atlas failed for $name, trying direct disk atlas: $e');
			menuItem.frames = loadMenuAtlasFromDisk(name);
		}

		if (menuItem.frames != null)
		{
			var idleState:String = (name == 'play' || name == 'mods' || name == 'credits' || name == 'options') ? 'basic' : 'idle';
			var selectedState:String = (name == 'play' || name == 'mods' || name == 'credits' || name == 'options') ? 'white' : 'selected';
			menuItem.animation.addByPrefix('idle', '$name $idleState', 24, true);
			menuItem.animation.addByPrefix('selected', '$name $selectedState', 24, true);
			menuItem.animation.play('idle');
		}
		else
		{
			var fallbackBitmap:Null<BitmapData> = loadMenuBitmapFromDisk(name);
			if (fallbackBitmap != null)
			{
				menuItem.loadGraphic(fallbackBitmap);
			}
			else
			{
				trace('Main menu image missing for $name; using transparent placeholder.');
				menuItem.makeGraphic(360, 80, FlxColor.TRANSPARENT);
			}
		}
		menuItem.updateHitbox();

		menuItem.antialiasing = ClientPrefs.data.antialiasing;
		menuItem.scrollFactor.set();
		menuItem.ID = menuItems.length;
		menuItems.add(menuItem);
		return menuItem;
	}

	function tweenMenuItemIn(item:FlxSprite):Void
	{
		var targetX:Float = item.x;
		item.x = -800;
		FlxTween.tween(item, {x: targetX}, 1.3, {ease: FlxEase.expoInOut});
	}

	function tweenMenuItemOut(item:FlxSprite):Void
	{
		FlxTween.cancelTweensOf(item);
		FlxTween.tween(item, {x: -600}, 0.6, {
			ease: FlxEase.backIn,
			onComplete: function(_:FlxTween) item.kill()
		});
	}

	function switchMenuOption(option:String, item:FlxSprite):Void
	{
		switch (option)
		{
			case 'story_mode':
				MusicBeatState.switchState(backend.ScriptableState.tryCreateLazy('StoryMenuState', function() return new StoryMenuState()));
			case 'freeplay':
				MusicBeatState.switchState(FreeplayStateSelector.create());
			case 'play':
				MusicBeatState.switchState(backend.ScriptableState.tryCreateLazy('PlaySelectionState', function() return new PlaySelectionState()));

			#if MODS_ALLOWED
			case 'mods':
				MusicBeatState.switchState(backend.ScriptableState.tryCreateLazy('ModsMenuState', function() return new ModsMenuState()));
			#end

			#if ACHIEVEMENTS_ALLOWED
			case 'achievements':
				MusicBeatState.switchState(backend.ScriptableState.tryCreateLazy('AchievementsMenuState', function() return new AchievementsMenuState()));
			#end

			case 'credits':
				MusicBeatState.switchState(backend.ScriptableState.tryCreateLazy('CreditsState', function() return new CreditsState()));
			case 'options':
				MusicBeatState.switchState(backend.ScriptableState.tryCreateLazy('OptionsState', function() return new OptionsState()));
				OptionsState.onPlayState = false;
				if (PlayState.SONG != null)
				{
					Reflect.setField(PlayState.SONG, 'arrowSkin', null);
					Reflect.setField(PlayState.SONG, 'splashSkin', null);
					PlayState.stageUI = 'normal';
				}
			default:
				trace('Menu Item ${option} doesn\'t do anything');
				selectedSomethin = false;
				item.visible = true;
		}
	}

	function loadMenuAtlasFromDisk(name:String):Null<FlxAtlasFrames>
	{
		var base:String = 'assets/shared/images/mainmenu/menu_$name';
		var png:String = '$base.png';
		var xml:String = '$base.xml';

		if (!FileSystem.exists(png) || !FileSystem.exists(xml))
			return null;

		try
		{
			var bitmap:BitmapData = BitmapData.fromFile(png);
			if (bitmap == null)
				return null;
			return FlxAtlasFrames.fromSparrow(bitmap, File.getContent(xml));
		}
		catch (e:Dynamic)
		{
			trace('Direct main menu atlas failed for $name: $e');
		}

		return null;
	}

	function loadMenuBitmapFromDisk(name:String):Null<BitmapData>
	{
		var png:String = 'assets/shared/images/mainmenu/menu_$name.png';
		if (!FileSystem.exists(png))
			return null;

		try
		{
			return BitmapData.fromFile(png);
		}
		catch (e:Dynamic)
		{
			trace('Direct main menu image failed for $name: $e');
		}

		return null;
	}

	var selectedSomethin:Bool = false;

	var timeNotMoving:Float = 0;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		checker.x -= 0.45 * elapsed * 60;
		checker.y -= 0.16 * elapsed * 60;

		#if CHECK_FOR_UPDATES
		tryShowOutdatedWarning();
		#end

		for (i in 0...optionShit.length)
		{
			var item:FlxSprite = menuItems.members[i];
			var selected:Bool = curColumn == MainMenuColumn.CENTER && i == curSelected;
			var targetScale:Float = selected ? 1 : 0.7;
			var targetY:Float = (i * 175) + (selected ? -50 : 0);
			var lerpAmount:Float = Math.min(elapsed * 9, 1);
			item.scale.set(FlxMath.lerp(item.scale.x, targetScale, lerpAmount), FlxMath.lerp(item.scale.y, targetScale, lerpAmount));
			item.y = FlxMath.lerp(item.y, targetY, lerpAmount);
			item.updateHitbox();
		}

		if (!selectedSomethin && !isMenuInputBlocked())
		{
			if (controls.UI_UP_P)
				changeItem(-1);

			if (controls.UI_DOWN_P)
				changeItem(1);

			var allowMouse:Bool = allowMouse;
			if (allowMouse
				&& ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0)
					|| FlxG.mouse.justPressed)) // FlxG.mouse.deltaScreenX/Y checks is more accurate than FlxG.mouse.justMoved
			{
				allowMouse = false;
				FlxG.mouse.visible = true;
				timeNotMoving = 0;

				var selectedItem:FlxSprite;
				switch (curColumn)
				{
					case MainMenuColumn.CENTER:
						selectedItem = menuItems.members[curSelected];
					case MainMenuColumn.LEFT:
						selectedItem = leftItem;
					case MainMenuColumn.RIGHT:
						selectedItem = rightItem;
				}

				if (leftItem != null && FlxG.mouse.overlaps(leftItem))
				{
					allowMouse = true;
					if (selectedItem != leftItem)
					{
						curColumn = MainMenuColumn.LEFT;
						changeItem();
					}
				}
				else if (rightItem != null && FlxG.mouse.overlaps(rightItem))
				{
					allowMouse = true;
					if (selectedItem != rightItem)
					{
						curColumn = MainMenuColumn.RIGHT;
						changeItem();
					}
				}
				else
				{
					var dist:Float = -1;
					var distItem:Int = -1;
					for (i in 0...optionShit.length)
					{
						var memb:FlxSprite = menuItems.members[i];
						if (FlxG.mouse.overlaps(memb))
						{
							var distance:Float = Math.sqrt(Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.screenX, 2)
								+ Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.screenY, 2));
							if (dist < 0 || distance < dist)
							{
								dist = distance;
								distItem = i;
								allowMouse = true;
							}
						}
					}

					if (distItem != -1 && selectedItem != menuItems.members[distItem])
					{
						curColumn = MainMenuColumn.CENTER;
						curSelected = distItem;
						changeItem();
					}
				}
			}
			else
			{
				timeNotMoving += elapsed;
				if (timeNotMoving > 2)
					FlxG.mouse.visible = false;
			}

			switch (curColumn)
			{
				case MainMenuColumn.CENTER:
					if (controls.UI_LEFT_P && leftOption != null)
					{
						curColumn = MainMenuColumn.LEFT;
						changeItem();
					}
					else if (controls.UI_RIGHT_P && rightOption != null)
					{
						curColumn = MainMenuColumn.RIGHT;
						changeItem();
					}

				case MainMenuColumn.LEFT:
					if (controls.UI_RIGHT_P)
					{
						curColumn = MainMenuColumn.CENTER;
						changeItem();
					}

				case MainMenuColumn.RIGHT:
					if (controls.UI_LEFT_P)
					{
						curColumn = MainMenuColumn.CENTER;
						changeItem();
					}
			}

			var pressedBack:Bool = controls.BACK #if android || FlxG.android.justReleased.BACK #end;
			if (pressedBack)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxTween.tween(FlxG.camera, {zoom: 3}, 0.6, {ease: FlxEase.expoIn});
				FlxTween.tween(bg, {angle: 35}, 0.6, {ease: FlxEase.expoIn});
				#if DISCORD_ALLOWED
				DiscordClient.changePresence(Language.getPhrase('states.main_menu.title', 'Back to the Title Screen.'), null);
				#end
				MusicBeatState.switchState(backend.ScriptableState.tryCreateLazy('TitleState', function() return new TitleState()));
			}
			#if android
			else if (touchPad != null && touchPad.buttonX.justPressed)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				AndroidTools.finishActivity();
				return;
			}
			#end

			if (controls.ACCEPT || (FlxG.mouse.overlaps(menuItems, FlxG.camera) && FlxG.mouse.justPressed && allowMouse))
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				selectedSomethin = true;
				FlxG.mouse.visible = false;

				if (ClientPrefs.data.flashing)
					FlxFlicker.flicker(magenta, 1.1, 0.15, false);

				var item:FlxSprite;
				var option:String;
				switch (curColumn)
				{
					case MainMenuColumn.CENTER:
						option = optionShit[curSelected];
						item = menuItems.members[curSelected];

					case MainMenuColumn.LEFT:
						option = leftOption;
						item = leftItem;

					case MainMenuColumn.RIGHT:
						option = rightOption;
						item = rightItem;
				}

				#if DISCORD_ALLOWED
				DiscordClient.changePresence(Language.getPhrase('states.main_menu.chosen', 'Chosen: ') + option.toUpperCase(), null);
				#end

				for (memb in menuItems)
				{
					if (memb == null || memb == item)
						continue;
					tweenMenuItemOut(memb);
				}
				if (leftItem != null && leftItem != item)
					tweenMenuItemOut(leftItem);
				if (rightItem != null && rightItem != item)
					tweenMenuItemOut(rightItem);

				FlxTween.tween(FlxG.camera, {zoom: 5}, 0.8, {ease: FlxEase.expoIn});
				FlxTween.tween(bg, {angle: 45}, 0.8, {ease: FlxEase.expoIn});
				new FlxTimer().start(0.35, function(_)
				{
					switchMenuOption(option, item);
				});
			}
			else if (controls.justPressed('debug_1') || touchPad.buttonE.justPressed)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(backend.ScriptableState.tryCreate('MasterEditorMenu', new MasterEditorMenu()));
			}
		}

		super.update(elapsed);
	}

	function isMenuInputBlocked():Bool
	{
		if (menuItems == null)
			return false;
		return Reflect.field(menuItems, 'enabled') == false || Reflect.field(menuItems, 'busy') == true;
	}

	function changeItem(change:Int = 0)
	{
		if (change != 0)
			curColumn = MainMenuColumn.CENTER;
		curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'));

		for (item in menuItems)
		{
			if (item.animation.getByName('idle') != null)
				item.animation.play('idle');
			item.centerOffsets();
		}

		var selectedItem:FlxSprite;
		switch (curColumn)
		{
			case MainMenuColumn.CENTER:
				selectedItem = menuItems.members[curSelected];
			case MainMenuColumn.LEFT:
				selectedItem = leftItem;
			case MainMenuColumn.RIGHT:
				selectedItem = rightItem;
		}
		if (selectedItem.animation.getByName('selected') != null)
			selectedItem.animation.play('selected');
		selectedItem.centerOffsets();
		camFollow.x = selectedItem.getGraphicMidpoint().x;
		camFollow.y = selectedItem.getGraphicMidpoint().y;
		#if DISCORD_ALLOWED
		var selectedOption:String = switch (curColumn)
		{
			case MainMenuColumn.CENTER: optionShit[curSelected];
			case MainMenuColumn.LEFT: leftOption;
			case MainMenuColumn.RIGHT: rightOption;
		};
		DiscordClient.changePresence(Language.getPhrase('states.main_menu.presence2', 'Main Menu: ') + selectedOption.toUpperCase(), null);
		#end
	}
}

class PlusMainMenuItemGroup extends FlxTypedGroup<FlxSprite>
{
	public function new()
	{
		super();
	}

	public function addItem(id:String, item:FlxSprite):FlxSprite
	{
		return add(item);
	}
}