package states;

import backend.Mods;
import backend.WeekData;
import backend.Difficulty;
import backend.ModeDifficulty;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxBackdrop;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Json;
import substates.Marathon_Substate;
import sys.FileSystem;
import sys.io.File;

using StringTools;

typedef MarathonVars =
{
	var songNames:Array<String>;
	var songDifficulties:Array<String>;
	var ?songFolders:Array<String>;
}

class MenuMarathon extends MusicBeatState
{
	public static var _marathon:MarathonVars;
	public static var curSelected:Int = 0;
	public static var curDifficulty:Int = 2;
	public static var lastDifficultyName:String = 'Normal';
	public static var substated:Bool = false;
	public static var no:Bool = false;

	var songs:Array<SongTitles> = [];
	var grpSongs:FlxTypedGroup<Alphabet>;
	var bg:FlxSprite;
	var checker:FlxBackdrop;
	var side:FlxSprite;
	var difficultyIcon:FlxSprite;
	var diffText:FlxText;
	var tracksUsed:FlxText;
	var scoreText:FlxText;
	var emptyText:FlxText;
	var selectable:Bool = false;

	override function create()
	{
		substated = false;
		no = false;

		PlayState.isStoryMode = false;
		PlayState.isEndless = false;
		PlayState.isMarathon = true;
		PlayState.isFreeplay = false;
		PlayState.isSurvival = false;
		persistentUpdate = true;
		persistentDraw = true;

		lime.app.Application.current.window.title = lime.app.Application.current.meta.get('name');
		loadCurrent();
		buildSongList();
		validatePlaylist();
		if (curSelected < 0 || curSelected >= songs.length)
			curSelected = 0;

		bg = new FlxSprite().loadGraphic(Paths.image('MicUp/MaraBG_Main'));
		bg.scrollFactor.set();
		bg.setGraphicSize(Std.int(FlxG.width * 1.1), Std.int(FlxG.height * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		checker = new FlxBackdrop(Paths.image('MicUp/Mara_Checker'), flixel.util.FlxAxes.XY);
		checker.scrollFactor.set();
		checker.velocity.set(-0.67, 0.2);
		add(checker);

		side = new FlxSprite().loadGraphic(Paths.image('MicUp/Mara_Bottom'));
		side.scrollFactor.set();
		side.antialiasing = ClientPrefs.data.antialiasing;
		side.screenCenter(X);
		side.y = FlxG.height - side.height;
		add(side);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);
		for (i in 0...songs.length)
		{
			var label:String = songs[i].songName;
			if (songs[i].folder.length > 0 && songs[i].folder != Mods.BASE_GAME_MOD_FOLDER)
				label += ' [' + songs[i].folder + ']';
			var item:Alphabet = new Alphabet(308, 30 + (70 * i), label, true);
			item.targetY = i;
			grpSongs.add(item);
		}

		difficultyIcon = new FlxSprite();
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
		difficultyIcon.antialiasing = true;
		difficultyIcon.y = FlxG.height - difficultyIcon.height - 8;
		difficultyIcon.screenCenter(X);
		add(difficultyIcon);

		diffText = new FlxText(0, 0, FlxG.width, '', 24);
		diffText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER);
		diffText.setBorderStyle(OUTLINE, FlxColor.BLACK, 4, 1);
		diffText.alignment = CENTER;
		add(diffText);

		tracksUsed = new FlxText(0, 680, FlxG.width, '0 TRACKS USED', 32);
		tracksUsed.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, RIGHT);
		tracksUsed.setBorderStyle(OUTLINE, FlxColor.BLACK, 5, 1);
		add(tracksUsed);

		scoreText = new FlxText(0, 0, FlxG.width, 'PERSONAL BEST:0', 32);
		scoreText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER);
		scoreText.setBorderStyle(OUTLINE, FlxColor.BLACK, 5, 1);
		scoreText.y = difficultyIcon.y - 38;
		add(scoreText);

		if (songs.length == 0)
		{
			emptyText = new FlxText(0, 0, FlxG.width, 'NO SONGS AVAILABLE', 32);
			emptyText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER);
			emptyText.setBorderStyle(OUTLINE, FlxColor.BLACK, 4, 1);
			emptyText.screenCenter();
			add(emptyText);
		}

		changeSelection(0);
		new FlxTimer().start(0.35, function(_) selectable = true);
		super.create();
		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Selecting Marathon tracks', null);
		#end
	}

	function buildSongList():Void
	{
		songs = [];
		Mods.loadTopMod();
		WeekData.reloadWeekFiles(false);
		for (weekName in WeekData.weeksList)
		{
			var week:WeekData = WeekData.weeksLoaded.get(weekName);
			if (week == null || weekIsLocked(weekName))
				continue;
			WeekData.setDirectoryFromWeek(week);
			for (song in week.songs)
			{
				var folder:String = Mods.currentModDirectory != null ? Mods.currentModDirectory : '';
				songs.push(new SongTitles(song[0], folder, ModeDifficulty.available(song[0], week.difficulties)));
			}
		}

		Mods.loadTopMod();
		var listPath:String = Paths.txt('freeplaySonglist');
		var listFolder:String = Paths.getModFolderNameFromPath(listPath);
		if (listFolder == null)
			listFolder = '';
		Mods.currentModDirectory = listFolder;
		for (entry in CoolUtil.coolTextFile(listPath))
		{
			var name:String = entry.split(':')[0];
			if (name == null || name.trim().length == 0)
				continue;
			var exists:Bool = false;
			for (song in songs)
				if (song.folder == listFolder && Paths.formatToSongPath(song.songName) == Paths.formatToSongPath(name))
					exists = true;
			if (!exists)
				songs.push(new SongTitles(name.trim(), listFolder, ModeDifficulty.available(name.trim())));
		}
		Mods.loadTopMod();
	}

	function validatePlaylist():Void
	{
		var invalid:Bool = PlayState.storyPlaylist.length != PlayState.difficultyPlaylist.length
			|| PlayState.storyPlaylist.length != PlayState.storyFolderPlaylist.length;
		var changed:Bool = false;
		if (!invalid)
		{
			for (i in 0...PlayState.storyPlaylist.length)
			{
				var songName:String = PlayState.storyPlaylist[i];
				var folder:String = PlayState.storyFolderPlaylist[i];
				var difficulty:String = ModeDifficulty.fromPlaylist(PlayState.difficultyPlaylist[i]);
				var matchedDifficulty:Null<String> = null;
				for (song in songs)
				{
					if (song.folder == folder && Paths.formatToSongPath(song.songName) == Paths.formatToSongPath(songName))
					{
						matchedDifficulty = ModeDifficulty.findAvailable(song.difficulties, difficulty);
						break;
					}
				}
				if (matchedDifficulty == null)
				{
					invalid = true;
					break;
				}
				if (PlayState.difficultyPlaylist[i] != matchedDifficulty)
				{
					PlayState.difficultyPlaylist[i] = matchedDifficulty;
					changed = true;
				}
			}
		}

		if (invalid)
		{
			PlayState.storyPlaylist = [];
			PlayState.difficultyPlaylist = [];
			PlayState.storyFolderPlaylist = [];
			saveCurrent();
		}
		else if (changed)
			saveCurrent();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		checker.x -= -0.67 / (ClientPrefs.data.framerate / 60);
		checker.y -= 0.2 / (ClientPrefs.data.framerate / 60);
		tracksUsed.text = PlayState.storyPlaylist.length + ' TRACKS USED';
		tracksUsed.x = 1240 - tracksUsed.width;

		for (i in 0...grpSongs.members.length)
		{
			var item:Alphabet = grpSongs.members[i];
			item.targetY = i - curSelected;
			var scaledY:Float = FlxMath.remapToRange(item.targetY, 0, 1, 0, 1.3);
			item.y = FlxMath.lerp(item.y, (scaledY * 120) + (FlxG.height * 0.5), 0.16 / (ClientPrefs.data.framerate / 60));
			item.x = FlxMath.lerp(item.x, 308, 0.16 / (ClientPrefs.data.framerate / 60));
			item.alpha = item.targetY == 0 ? 1 : 0.6;
		}

		if (selectable && !substated)
		{
			if (songs.length > 0)
			{
				if (controls.UI_UP_P)
					changeSelection(-1);
				if (controls.UI_DOWN_P)
					changeSelection(1);
			}
			if (controls.UI_LEFT_P)
				changeDifficulty(-1);
			if (controls.UI_RIGHT_P)
				changeDifficulty(1);

			if (controls.BACK)
			{
				substated = true;
				FlxG.sound.play(Paths.sound('cancelMenu'), 100);
				openSubState(new Marathon_Substate());
			}
			if (controls.ACCEPT && songs.length > 0 && songs[curSelected].difficulties.length > 0)
			{
				var difficulty:String = songs[curSelected].difficulties[curDifficulty];
				PlayState.difficultyPlaylist.push(difficulty);
				PlayState.storyPlaylist.push(songs[curSelected].songName.toLowerCase());
				PlayState.storyFolderPlaylist.push(songs[curSelected].folder);
				saveCurrent();
				FlxG.sound.play(Paths.sound('confirmMenu'), 100);
			}
		}

		if (no)
		{
			bg.visible = false;
			checker.visible = false;
			side.visible = false;
			difficultyIcon.visible = false;
			tracksUsed.visible = false;
			scoreText.visible = false;
			diffText.visible = false;
			grpSongs.visible = false;
		}
	}

	function changeSelection(change:Int = 0):Void
	{
		if (songs.length == 0)
		{
			curSelected = 0;
			scoreText.text = 'PERSONAL BEST:0';
			updateDifficultyDisplay();
			return;
		}
		curSelected += change;
		if (curSelected < 0)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = 0;
		if (change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'), 100);
		#if !switch
		scoreText.text = 'PERSONAL BEST:' + Std.string(Std.int(FlxG.save.data.marathonScore));
		#end
		Difficulty.copyFrom(songs[curSelected].difficulties);
		var defaultIndex:Int = Difficulty.list.indexOf(Difficulty.getDefault());
		var matchingLast:Null<String> = ModeDifficulty.findAvailable(Difficulty.list, lastDifficultyName);
		var lastIndex:Int = matchingLast != null ? Difficulty.list.indexOf(matchingLast) : -1;
		curDifficulty = lastIndex >= 0 ? lastIndex : (defaultIndex >= 0 ? defaultIndex : 0);
		updateDifficultyDisplay();
	}

	function changeDifficulty(change:Int = 0):Void
	{
		if (songs.length == 0 || songs[curSelected].difficulties.length == 0)
			return;
		Difficulty.copyFrom(songs[curSelected].difficulties);
		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length - 1);
		updateDifficultyDisplay();
	}

	function updateDifficultyDisplay():Void
	{
		if (songs.length == 0 || songs[curSelected].difficulties.length == 0)
		{
			difficultyIcon.visible = false;
			diffText.visible = false;
			return;
		}

		Difficulty.copyFrom(songs[curSelected].difficulties);
		curDifficulty = Std.int(FlxMath.bound(curDifficulty, 0, Difficulty.list.length - 1));
		var difficulty:String = Difficulty.getString(curDifficulty, false);
		lastDifficultyName = difficulty;
		switch (difficulty.toLowerCase())
		{
			case 'noob', 'easy', 'normal', 'hard', 'expert', 'insane', 'crazy', 'flip', 'fucked', 'hell', 'remix':
				difficultyIcon.animation.play(difficulty.toLowerCase());
				difficultyIcon.visible = true;
				diffText.visible = false;
			default:
				difficultyIcon.visible = false;
				diffText.visible = true;
				diffText.text = Difficulty.list.length > 1
					? '< ' + difficulty.toUpperCase() + ' >'
					: difficulty.toUpperCase();
		}
		difficultyIcon.screenCenter(X);
		difficultyIcon.y = FlxG.height - difficultyIcon.height - 8;
		diffText.x = difficultyIcon.x + (difficultyIcon.width - diffText.width) / 2;
		diffText.y = difficultyIcon.y + (difficultyIcon.height - diffText.height) / 2;
	}

	function weekIsLocked(name:String):Bool
	{
		var week:WeekData = WeekData.weeksLoaded.get(name);
		return week != null && !week.startUnlocked && week.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(week.weekBefore) || !StoryMenuState.weekCompleted.get(week.weekBefore));
	}

	function loadCurrent():Void
	{
		if (!FileSystem.isDirectory('presets/marathon'))
			FileSystem.createDirectory('presets/marathon');

		var path:String = 'presets/marathon/current';
		if (!FileSystem.exists(path))
		{
			_marathon = {songDifficulties: [], songNames: [], songFolders: []};
			PlayState.difficultyPlaylist = [];
			PlayState.storyPlaylist = [];
			PlayState.storyFolderPlaylist = [];
			saveCurrent();
			return;
		}
		try
		{
			_marathon = Json.parse(File.getContent(path));
			PlayState.difficultyPlaylist = _marathon.songDifficulties != null ? _marathon.songDifficulties : [];
			PlayState.storyPlaylist = _marathon.songNames != null ? _marathon.songNames : [];
			restoreSongFolders(_marathon.songFolders);
		}
		catch (_:Dynamic)
		{
			_marathon = {songDifficulties: [], songNames: [], songFolders: []};
			PlayState.difficultyPlaylist = [];
			PlayState.storyPlaylist = [];
			PlayState.storyFolderPlaylist = [];
		}
	}

	public static function saveCurrent():Void
	{
		if (!FileSystem.isDirectory('presets/marathon'))
			FileSystem.createDirectory('presets/marathon');
		_marathon = {
			songDifficulties: PlayState.difficultyPlaylist,
			songNames: PlayState.storyPlaylist,
			songFolders: PlayState.storyFolderPlaylist
		};
		File.saveContent('presets/marathon/current', Json.stringify(_marathon, null, '\t'));
	}

	public static function loadPreset(input:String):Void
	{
		_marathon = Json.parse(File.getContent('presets/marathon/' + input));
		PlayState.difficultyPlaylist = _marathon.songDifficulties != null ? _marathon.songDifficulties : [];
		PlayState.storyPlaylist = _marathon.songNames != null ? _marathon.songNames : [];
		restoreSongFolders(_marathon.songFolders);
		saveCurrent();
	}

	public static function savePreset(input:String):Void
	{
		if (!FileSystem.isDirectory('presets/marathon'))
			FileSystem.createDirectory('presets/marathon');
		_marathon = {
			songDifficulties: PlayState.difficultyPlaylist,
			songNames: PlayState.storyPlaylist,
			songFolders: PlayState.storyFolderPlaylist
		};
		File.saveContent('presets/marathon/' + input, Json.stringify(_marathon, null, '\t'));
	}

	static function restoreSongFolders(folders:Array<String>):Void
	{
		PlayState.storyFolderPlaylist = folders != null ? folders.copy() : [];
		while (PlayState.storyFolderPlaylist.length < PlayState.storyPlaylist.length)
			PlayState.storyFolderPlaylist.push(Mods.currentModDirectory != null ? Mods.currentModDirectory : '');
		while (PlayState.storyFolderPlaylist.length > PlayState.storyPlaylist.length)
			PlayState.storyFolderPlaylist.pop();
	}
}

class SongTitles
{
	public var songName:String;
	public var folder:String;
	public var difficulties:Array<String>;
	public function new(song:String, folder:String, difficulties:Array<String>)
	{
		songName = song;
		this.folder = folder;
		this.difficulties = difficulties;
	}
}
