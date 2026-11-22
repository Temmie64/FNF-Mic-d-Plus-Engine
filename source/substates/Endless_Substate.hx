package substates;

import backend.Mods;
import backend.Song;
import backend.AccuracyTools;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
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
	public static var difficulties:String = '';

	var optionNames:Array<String> = ['difficulty', 'speed', 'ramp', 'play'];
	var menuItems:FlxTypedGroup<FlxSprite>;
	var difficultyIcon:FlxSprite;
	var diffText:FlxText;
	var speedText:FlxText;
	var rampText:FlxText;
	var chartAvailable:Bool = false;
	var selectable:Bool = false;
	var closing:Bool = false;
	var camLerp:Float = 0.16;
    var initSpeed:Float = 0.16;
    var blackBarThingie:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 1, FlxColor.BLACK);

	public function new()
	{
		super();
		_endless = {speed: 0, ramp: true};
		Mods.currentModDirectory = songFolder != null ? songFolder : '';

		add(blackBarThingie);
        blackBarThingie.scrollFactor.set();
        blackBarThingie.scale.y = 0;
        FlxTween.tween(blackBarThingie, { 'scale.y': 500}, 0.5, { ease: FlxEase.expoOut});

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
		difficultyIcon.frames = Paths.getSparrowAtlas('MicUp/difficulties');
		difficultyIcon.animation.addByPrefix('noob', 'NOOB');
		difficultyIcon.animation.addByPrefix('easy', 'EASY');
		difficultyIcon.animation.addByPrefix('normal', 'NORMAL');
		difficultyIcon.animation.addByPrefix('hard', 'HARD');
		difficultyIcon.animation.addByPrefix('expert', 'EXPERT');
		difficultyIcon.animation.addByPrefix('insane', 'INSANE');
		difficultyIcon.animation.addByPrefix('crazy', 'CRAZY');
		difficultyIcon.animation.addByPrefix('flip', 'FLIP');
		difficultyIcon.animation.addByPrefix('fucked', 'FUCKED');
		difficultyIcon.animation.addByPrefix('hell', 'HELL');
		difficultyIcon.animation.addByPrefix('remix', 'REMIX');
		difficultyIcon.scrollFactor.set();
		difficultyIcon.antialiasing = true;
		add(difficultyIcon);

		diffText = new FlxText(900, 151, 320, '', 32);
		diffText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER);
		diffText.setBorderStyle(OUTLINE, FlxColor.BLACK, 5, 1);
		diffText.scrollFactor.set();
		add(diffText);

		speedText = makeText(910, 283);
		rampText = makeText(910, 403);

		curSelected = Std.int(FlxMath.bound(curSelected, 0, optionNames.length - 1));
		loadDifficulties();
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

		blackBarThingie.y = 360 - blackBarThingie.height/2;
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
			PlayState.campaignMisses = 0;
			PlayState.campaignFlawlesss = 0;
			PlayState.campaignSicks = 0;
			PlayState.campaignGoods = 0;
			PlayState.campaignBads = 0;
			PlayState.campaignShits = 0;
			PlayState.campaignMaxCombo = 0;
			PlayState.campaignTotalNotes = 0;
			PlayState.campaignAccuracySum = 0;
			PlayState.campaignSongsCount = 0;
			PlayState.endlessCombo = 0;
			PlayState.endlessTotalPlayed = 0;
			PlayState.endlessTotalNotesHit = 0;
			PlayState.endlessTotalNotes = 0;
			PlayState.endlessBonusLimit = AccuracyTools.BONUS_MAX;
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
		if (Difficulty.list == null || Difficulty.list.length == 0)
			loadDifficulties();
		if (Difficulty.list.length == 0)
			Difficulty.list = ['Normal'];

		curDifficulty += change;
		if (curDifficulty < 0)
			curDifficulty = Difficulty.list.length - 1;
		if (curDifficulty >= Difficulty.list.length)
			curDifficulty = 0;

		PlayState.storyDifficulty = curDifficulty;
		playDifficultyAnimation(Difficulty.getString(curDifficulty));

		updateSong();
	}

	function loadDifficulties():Void
	{
		var candidates:Array<String> = [];
		if (difficulties != null && difficulties.trim().length > 0)
		{
			for (diff in difficulties.trim().split(','))
			{
				diff = diff.trim();
				if (diff.length > 0 && !candidates.contains(diff))
					candidates.push(diff);
			}
		}
		if (Difficulty.list == null)
			Difficulty.resetList();
		for (diff in Difficulty.list)
			if (diff != null && diff.length > 0 && !candidates.contains(diff))
				candidates.push(diff);
		for (diff in Difficulty.defaultList)
			if (!candidates.contains(diff))
				candidates.push(diff);

		for (diff in ['Noob', 'Expert', 'Insane', 'Crazy', 'Flip', 'Fucked', 'Hell', 'Remix', 'Erect', 'Nightmare'])
			if (!candidates.contains(diff))
				candidates.push(diff);

		var available:Array<String> = [];
		for (diff in candidates)
		{
			var request:String = chartRequestName(diff);
			if (Song.resolveChartPath(request, song) != null)
				available.push(diff);
		}

		if (available.length == 0)
		{
			var baseRequest:String = Paths.formatToSongPath(song);
			if (Song.resolveChartPath(baseRequest, song) != null)
				available.push(Difficulty.getDefault());
			else
				available.push(Difficulty.getDefault());
		}

		Difficulty.copyFrom(available);
		var defaultIndex:Int = Difficulty.list.indexOf(Difficulty.getDefault());
		curDifficulty = defaultIndex >= 0 ? defaultIndex : 0;
	}

	function chartRequestName(diff:String):String
	{
		var formatted:String = Paths.formatToSongPath(diff);
		if (formatted == Paths.formatToSongPath(Difficulty.getDefault()))
			return Paths.formatToSongPath(song);
		return Paths.formatToSongPath(song) + '-' + formatted;
	}

	function playDifficultyAnimation(difficulty:String):Void
	{
		var animationName:String = difficulty.toLowerCase();
		switch (animationName)
		{
			case 'noob', 'easy', 'normal', 'hard', 'expert', 'insane', 'crazy', 'flip', 'fucked', 'hell', 'remix':
				difficultyIcon.animation.play(animationName);
				difficultyIcon.visible = true;
				diffText.alpha = 0;
			default:
				difficultyIcon.visible = false;
				diffText.alpha = 1;
				diffText.alignment = CENTER;
				diffText.setBorderStyle(OUTLINE, FlxColor.BLACK, 5, 1);
				diffText.text = Difficulty.list.length > 1
					? '< ' + difficulty.toUpperCase() + ' >'
					: difficulty.toUpperCase();
		}
	}

	function updateSong():Void
	{
		Mods.currentModDirectory = songFolder != null ? songFolder : '';
		var diffName:String = Difficulty.getString(curDifficulty, false);
		var request:String = chartRequestName(diffName);
		var loaded:SwagSong = Song.loadFromJson(request, song);
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
