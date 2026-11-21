package states;

import backend.Mods;
import backend.WeekData;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxBackdrop;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Json;
import substates.Survival_GameOptions;
import substates.Survival_Substate;
import sys.FileSystem;
import sys.io.File;

using StringTools;

typedef SurvivalVars =
{
	var songNames:Array<String>;
	var songDifficulties:Array<String>;
	var ?songFolders:Array<String>;
}

class MenuSurvival extends MusicBeatState
{
	public static var _survival:SurvivalVars;
	public static var curSelected:Int = 0;
	public static var curDifficulty:Int = 2;
	public static var substated:Bool = false;
	public static var no:Bool = false;

	var songs:Array<SongTitlesS> = [];
	var grpSongs:FlxTypedGroup<Alphabet>;
	var bg:FlxSprite;
	var checker:FlxBackdrop;
	var side:FlxSprite;
	var difficultyIcon:FlxSprite;
	var tracksUsed:FlxText;
	var emptyText:FlxText;
	var selectable:Bool = false;

	override function create()
	{
		substated = false;
		no = false;
		PlayState.isStoryMode = false;
		PlayState.isEndless = false;
		PlayState.isMarathon = false;
		PlayState.isFreeplay = false;
		PlayState.isSurvival = true;
		PlayState.timeLeftOver = 0;
		persistentUpdate = true;
		persistentDraw = true;

		lime.app.Application.current.window.title = lime.app.Application.current.meta.get('name');
		loadCurrent();
		Survival_GameOptions.load();
		buildSongList();
		if (curSelected < 0 || curSelected >= songs.length)
			curSelected = 0;

		bg = new FlxSprite().loadGraphic(Paths.image('MicUp/sBG_Main'));
		bg.scrollFactor.set();
		bg.setGraphicSize(Std.int(FlxG.width * 1.1), Std.int(FlxG.height * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		checker = new FlxBackdrop(Paths.image('MicUp/Survival_Checker'), flixel.util.FlxAxes.XY);
		checker.scrollFactor.set();
		checker.velocity.set(-0.67, 0.2);
		add(checker);

		side = new FlxSprite().loadGraphic(Paths.image('MicUp/Survival_Side'));
		side.scrollFactor.set();
		side.antialiasing = ClientPrefs.data.antialiasing;
		side.screenCenter(Y);
		side.x = -20 - side.width;
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

		tracksUsed = new FlxText(0, 635, FlxG.width - 40, '0/5 TRACKS USED', 32);
		tracksUsed.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, RIGHT);
		tracksUsed.setBorderStyle(OUTLINE, FlxColor.BLACK, 5, 1);
		tracksUsed.x = 1240 - tracksUsed.width;
		add(tracksUsed);

		difficultyIcon = new FlxSprite();
		difficultyIcon.frames = Paths.getSparrowAtlas('difficulties');
		difficultyIcon.animation.addByPrefix('noob', 'NOOB');
		difficultyIcon.animation.addByPrefix('easy', 'EASY');
		difficultyIcon.animation.addByPrefix('normal', 'NORMAL');
		difficultyIcon.animation.addByPrefix('hard', 'HARD');
		difficultyIcon.animation.addByPrefix('expert', 'EXPERT');
		difficultyIcon.animation.addByPrefix('insane', 'INSANE');
		difficultyIcon.antialiasing = true;
		difficultyIcon.x = 1240 - difficultyIcon.width;
		difficultyIcon.y = tracksUsed.y - difficultyIcon.height - 8;
		add(difficultyIcon);

		if (songs.length == 0)
		{
			emptyText = new FlxText(0, 0, FlxG.width, 'NO SONGS AVAILABLE', 32);
			emptyText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER);
			emptyText.setBorderStyle(OUTLINE, FlxColor.BLACK, 4, 1);
			emptyText.screenCenter();
			add(emptyText);
		}

		changeDifficulty(0);
		changeSelection(0);
		new FlxTimer().start(0.35, function(_) selectable = true);
		super.create();
		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Selecting Survival tracks', null);
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
				songs.push(new SongTitlesS(song[0], Mods.currentModDirectory != null ? Mods.currentModDirectory : ''));
		}

		Mods.loadTopMod();
		var listPath:String = Paths.txt('freeplaySonglist');
		var listFolder:String = Paths.getModFolderNameFromPath(listPath);
		if (listFolder == null)
			listFolder = '';
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
				songs.push(new SongTitlesS(name.trim(), listFolder));
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		checker.x -= -0.67 / (ClientPrefs.data.framerate / 60);
		checker.y -= 0.2 / (ClientPrefs.data.framerate / 60);

		tracksUsed.text = PlayState.storyPlaylist.length + '/5 TRACKS USED';
		tracksUsed.x = 1240 - tracksUsed.width;

		for (i in 0...grpSongs.members.length)
		{
			var item:Alphabet = grpSongs.members[i];
			item.targetY = i - curSelected;
			var scaledY:Float = FlxMath.remapToRange(item.targetY, 0, 1, 0, 1.3);
			item.y = FlxMath.lerp(item.y, (scaledY * 120) + (FlxG.height * 0.5), 0.16 / (ClientPrefs.data.framerate / 60));
			item.x = FlxMath.lerp(item.x, 263, 0.16 / (ClientPrefs.data.framerate / 60));
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
				openSubState(new Survival_Substate());
			}
			if (controls.ACCEPT && songs.length > 0)
			{
				if (PlayState.difficultyPlaylist.length < 5)
				{
					PlayState.difficultyPlaylist.push(Std.string(curDifficulty));
					PlayState.storyPlaylist.push(songs[curSelected].songName.toLowerCase());
					PlayState.storyFolderPlaylist.push(songs[curSelected].folder);
					saveCurrent();
					FlxG.sound.play(Paths.sound('confirmMenu'), 100);
				}
				else
					FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), 0.15);
			}
		}

		if (no)
		{
			bg.visible = false;
			checker.visible = false;
			side.visible = false;
			difficultyIcon.visible = false;
			tracksUsed.visible = false;
			grpSongs.visible = false;
		}
	}

	function changeSelection(change:Int = 0):Void
	{
		if (songs.length == 0)
		{
			curSelected = 0;
			return;
		}
		curSelected += change;
		if (curSelected < 0)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = 0;
		if (change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'), 100);
	}

	function changeDifficulty(change:Int = 0):Void
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
		difficultyIcon.x = 1240 - difficultyIcon.width;
		difficultyIcon.y = tracksUsed.y - difficultyIcon.height - 8;
	}

	function weekIsLocked(name:String):Bool
	{
		var week:WeekData = WeekData.weeksLoaded.get(name);
		return week != null && !week.startUnlocked && week.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(week.weekBefore) || !StoryMenuState.weekCompleted.get(week.weekBefore));
	}

	function loadCurrent():Void
	{
		if (!FileSystem.isDirectory('presets/survival'))
			FileSystem.createDirectory('presets/survival');
		var path:String = 'presets/survival/current';
		if (!FileSystem.exists(path))
		{
			_survival = {songDifficulties: [], songNames: [], songFolders: []};
			PlayState.difficultyPlaylist = [];
			PlayState.storyPlaylist = [];
			PlayState.storyFolderPlaylist = [];
			saveCurrent();
			return;
		}
		try
		{
			_survival = Json.parse(File.getContent(path));
			PlayState.difficultyPlaylist = _survival.songDifficulties != null ? _survival.songDifficulties : [];
			PlayState.storyPlaylist = _survival.songNames != null ? _survival.songNames : [];
			restoreSongFolders(_survival.songFolders);
		}
		catch (_:Dynamic)
		{
			_survival = {songDifficulties: [], songNames: [], songFolders: []};
			PlayState.difficultyPlaylist = [];
			PlayState.storyPlaylist = [];
			PlayState.storyFolderPlaylist = [];
		}
	}

	public static function saveCurrent():Void
	{
		if (!FileSystem.isDirectory('presets/survival'))
			FileSystem.createDirectory('presets/survival');
		_survival = {
			songDifficulties: PlayState.difficultyPlaylist,
			songNames: PlayState.storyPlaylist,
			songFolders: PlayState.storyFolderPlaylist
		};
		File.saveContent('presets/survival/current', Json.stringify(_survival, null, '\t'));
	}

	public static function loadPreset(input:String):Void
	{
		_survival = Json.parse(File.getContent('presets/survival/' + input));
		PlayState.difficultyPlaylist = _survival.songDifficulties != null ? _survival.songDifficulties : [];
		PlayState.storyPlaylist = _survival.songNames != null ? _survival.songNames : [];
		restoreSongFolders(_survival.songFolders);
		saveCurrent();
	}

	public static function savePreset(input:String):Void
	{
		if (!FileSystem.isDirectory('presets/survival'))
			FileSystem.createDirectory('presets/survival');
		_survival = {
			songDifficulties: PlayState.difficultyPlaylist,
			songNames: PlayState.storyPlaylist,
			songFolders: PlayState.storyFolderPlaylist
		};
		File.saveContent('presets/survival/' + input, Json.stringify(_survival, null, '\t'));
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

class SongTitlesS
{
	public var songName:String;
	public var folder:String;
	public function new(song:String, folder:String)
	{
		songName = song;
		this.folder = folder;
	}
}
