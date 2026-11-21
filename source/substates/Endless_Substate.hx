package substates;

import backend.Mods;
import backend.Song;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import states.MenuEndless;

using StringTools;

typedef EndlessVars =
{
	var speed:Float;
	var ramp:Bool;
}

class Endless_Substate extends MusicBeatSubstate
{
	public static var curSelected:Int = 0;
	public static var curDifficulty:Int = 2;
	public static var _endless:EndlessVars;
	public static var song:String = '';
	public static var songFolder:String = '';

	var optionNames:Array<String> = ['difficulty', 'speed', 'ramp', 'play'];
	var menuItems:FlxTypedGroup<FlxSprite>;
	var difficultyIcon:FlxSprite;
	var speedText:FlxText;
	var rampText:FlxText;
	var chartAvailable:Bool = false;
	var selectable:Bool = false;
	var closing:Bool = false;

	public function new()
	{
		super();
		_endless = {speed: 0, ramp: true};
		Mods.currentModDirectory = songFolder != null ? songFolder : '';

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		var atlas = Paths.getSparrowAtlas('MicUp/Endless_Buttons');
		for (i in 0...optionNames.length)
		{
			var item:FlxSprite = new FlxSprite(40, 40 + (i * 90));
			item.frames = atlas;
			item.animation.addByPrefix('idle', optionNames[i], 24, true);
			item.animation.play('idle');
			item.ID = i;
			item.scrollFactor.set();
			item.antialiasing = true;
			menuItems.add(item);
		}

		difficultyIcon = new FlxSprite(900, 151);
		difficultyIcon.frames = Paths.getSparrowAtlas('difficulties');
		difficultyIcon.animation.addByPrefix('noob', 'NOOB');
		difficultyIcon.animation.addByPrefix('easy', 'EASY');
		difficultyIcon.animation.addByPrefix('normal', 'NORMAL');
		difficultyIcon.animation.addByPrefix('hard', 'HARD');
		difficultyIcon.animation.addByPrefix('expert', 'EXPERT');
		difficultyIcon.animation.addByPrefix('insane', 'INSANE');
		difficultyIcon.scrollFactor.set();
		difficultyIcon.antialiasing = true;
		add(difficultyIcon);

		speedText = makeText(910, 283);
		rampText = makeText(910, 403);

		curSelected = Std.int(FlxMath.bound(curSelected, 0, optionNames.length - 1));
		curDifficulty = Std.int(FlxMath.bound(curDifficulty, 0, 5));
		changeDifficulty(0);

		new FlxTimer().start(0.1, function(_) selectable = true);
	}

	function makeText(x:Float, y:Float):FlxText
	{
		var text:FlxText = new FlxText(x, y, 320, '', 32);
		text.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER);
		text.setBorderStyle(OUTLINE, FlxColor.BLACK, 5, 1);
		text.scrollFactor.set();
		add(text);
		return text;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		speedText.text = chartAvailable ? Std.string(_endless.speed) : 'CHART UNAVAILABLE';
		rampText.text = Std.string(_endless.ramp).toUpperCase();

		if (!selectable || closing)
			return;

		if (controls.UI_UP_P)
		{
			changeItem(-1);
			FlxG.sound.play(Paths.sound('scrollMenu'), 100);
		}
		if (controls.UI_DOWN_P)
		{
			changeItem(1);
			FlxG.sound.play(Paths.sound('scrollMenu'), 100);
		}

		if (controls.UI_LEFT_P)
			changeOption(-1);
		if (controls.UI_RIGHT_P)
			changeOption(1);

		if (controls.BACK)
		{
			closing = true;
			FlxG.sound.play(Paths.sound('cancelMenu'), 100);
			closeAndReset();
		}

		if (controls.ACCEPT)
		{
			if (!chartAvailable)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'), 100);
				return;
			}

			PlayState.storyDifficulty = curDifficulty;
			PlayState.loops = 0;
			PlayState.speed = _endless.speed;
			PlayState.campaignScore = 0;
			closing = true;
			FlxG.sound.play(Paths.sound('confirmMenu'), 100);

			new FlxTimer().start(0.15, function(_)
			{
				MenuEndless.no = true;
				FlxG.state.closeSubState();
				FlxG.state.openSubState(new ChartType());
			});
		}

		for (item in menuItems.members)
		{
			var selected:Bool = item.ID == curSelected;
			item.scale.set(FlxMath.lerp(item.scale.x, selected ? 1.1 : 0.5, 0.16 / (ClientPrefs.data.framerate / 60)),
				FlxMath.lerp(item.scale.y, selected ? 1.1 : 0.5, 0.16 / (ClientPrefs.data.framerate / 60)));
		}
	}

	function closeAndReset():Void
	{
		new FlxTimer().start(0.15, function(_)
		{
			FlxG.state.closeSubState();
			MenuEndless.substated = false;
		});
	}

	function changeItem(change:Int):Void
	{
		curSelected += change;
		if (curSelected < 0)
			curSelected = optionNames.length - 1;
		if (curSelected >= optionNames.length)
			curSelected = 0;
	}

	function changeOption(change:Int):Void
	{
		switch (optionNames[curSelected])
		{
			case 'difficulty':
				changeDifficulty(change);
			case 'speed':
				_endless.speed = FlxMath.roundDecimal(FlxMath.bound(_endless.speed + (change * 0.1), 0.1, 8), 1);
				saveCurrent();
			case 'ramp':
				_endless.ramp = !_endless.ramp;
				saveCurrent();
		}
	}

	function changeDifficulty(change:Int):Void
	{
		curDifficulty += change;
		if (curDifficulty < 0)
			curDifficulty = 5;
		if (curDifficulty > 5)
			curDifficulty = 0;

		switch (curDifficulty)
		{
			case 0: difficultyIcon.animation.play('noob');
			case 1: difficultyIcon.animation.play('easy');
			case 2: difficultyIcon.animation.play('normal');
			case 3: difficultyIcon.animation.play('hard');
			case 4: difficultyIcon.animation.play('expert');
			case 5: difficultyIcon.animation.play('insane');
		}

		updateSong();
	}

	function updateSong():Void
	{
		var suffix:String = '';
		switch (curDifficulty)
		{
			case 0: suffix = '-noob';
			case 1: suffix = '-easy';
			case 3: suffix = '-hard';
			case 4: suffix = '-expert';
			case 5: suffix = '-insane';
		}

		Mods.currentModDirectory = songFolder != null ? songFolder : '';
		var loaded:SwagSong = Song.loadFromJson(song + suffix, song);
		chartAvailable = loaded != null;
		if (!chartAvailable)
		{
			_endless.speed = 0;
			return;
		}

		_endless.speed = loaded.speed;
		loadCurrent();
	}

	function loadCurrent():Void
	{
		if (!FileSystem.isDirectory('presets/endless'))
			FileSystem.createDirectory('presets/endless');

		var path:String = getPresetPath();
		if (!FileSystem.exists(path))
		{
			saveCurrent();
			return;
		}

		try
		{
			var parsed:Dynamic = Json.parse(File.getContent(path));
			if (parsed != null)
			{
				if (Reflect.hasField(parsed, 'speed'))
					_endless.speed = Std.parseFloat(Std.string(parsed.speed));
				if (Reflect.hasField(parsed, 'ramp'))
					_endless.ramp = parsed.ramp == true;
			}
		}
		catch (_:Dynamic)
		{
			saveCurrent();
		}
	}

	function saveCurrent():Void
	{
		if (!FileSystem.isDirectory('presets/endless'))
			FileSystem.createDirectory('presets/endless');

		File.saveContent(getPresetPath(), Json.stringify(_endless, null, '\t'));
	}

	function getPresetPath():String
	{
		var folder:String = songFolder != null && songFolder.length > 0
			? Paths.formatToSongPath(songFolder) + '_'
			: '';
		return 'presets/endless/' + folder + Paths.formatToSongPath(song) + '_' + curDifficulty;
	}
}
