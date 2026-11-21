package states;

import backend.Highscore;
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
import substates.Endless_Substate;

using StringTools;

class MenuEndless extends MusicBeatState
{
	public static var curSelected:Int = 0;
	public static var substated:Bool = false;
	public static var no:Bool = false;

	var songs:Array<SongTitlesE> = [];
	var grpSongs:FlxTypedGroup<Alphabet>;
	var bg:FlxSprite;
	var checker:FlxBackdrop;
	var side:FlxSprite;
	var scoreText:FlxText;
	var emptyText:FlxText;
	var selectable:Bool = false;

	override function create()
	{
		substated = false;
		no = false;
		curSelected = Std.int(FlxMath.bound(curSelected, 0, songs.length > 0 ? songs.length - 1 : 0));

		lime.app.Application.current.window.title = lime.app.Application.current.meta.get('name');

		PlayState.isStoryMode = false;
		PlayState.isEndless = true;
		PlayState.isMarathon = false;
		PlayState.isFreeplay = false;
		PlayState.isSurvival = false;

		persistentUpdate = true;
		persistentDraw = true;

		buildSongList();
		if (curSelected < 0 || curSelected >= songs.length)
			curSelected = 0;

		bg = new FlxSprite().loadGraphic(Paths.image('MicUp/miEndBG_Main'));
		bg.scrollFactor.set();
		bg.setGraphicSize(Std.int(FlxG.width * 1.1), Std.int(FlxG.height * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		checker = new FlxBackdrop(Paths.image('MicUp/End_Checker'), flixel.util.FlxAxes.XY);
		checker.scrollFactor.set();
		checker.velocity.set(0.2, 0.2);
		add(checker);

		side = new FlxSprite().loadGraphic(Paths.image('MicUp/End_Side'));
		side.scrollFactor.set();
		side.antialiasing = ClientPrefs.data.antialiasing;
		side.screenCenter();
		add(side);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var label:String = songs[i].songName;
			if (songs[i].folder.length > 0 && songs[i].folder != Mods.BASE_GAME_MOD_FOLDER)
				label += ' [' + songs[i].folder + ']';

			var songText:Alphabet = new Alphabet(0, 50 + (90 * i), label, true);
			songText.itemType = 'D-Shape';
			songText.targetY = i;
			grpSongs.add(songText);
		}

		scoreText = new FlxText(10, 5, FlxG.width - 20, 'PERSONAL BEST:\n0', 32);
		scoreText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, LEFT);
		scoreText.setBorderStyle(OUTLINE, FlxColor.BLACK, 5, 1);
		scoreText.screenCenter(Y);
		scoreText.x = 10;
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
				songs.push(new SongTitlesE(song[0], Mods.currentModDirectory != null ? Mods.currentModDirectory : ''));
		}

		Mods.loadTopMod();
		var legacyPath:String = Paths.txt('freeplaySonglist');
		var legacyFolder:String = Paths.getModFolderNameFromPath(legacyPath);
		if (legacyFolder == null)
			legacyFolder = '';

		for (entry in CoolUtil.coolTextFile(legacyPath))
		{
			var parts:Array<String> = entry.split(':');
			if (parts.length == 0 || parts[0] == null || parts[0].trim().length == 0)
				continue;

			var songName:String = parts[0].trim();
			var alreadyListed:Bool = false;
			for (song in songs)
			{
				if (song.folder == legacyFolder
					&& Paths.formatToSongPath(song.songName) == Paths.formatToSongPath(songName))
				{
					alreadyListed = true;
					break;
				}
			}
			if (!alreadyListed)
				songs.push(new SongTitlesE(songName, legacyFolder));
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		checker.x -= 0.27 / (ClientPrefs.data.framerate / 60);
		checker.y -= -0.2 / (ClientPrefs.data.framerate / 60);

		for (i in 0...grpSongs.members.length)
		{
			var item:Alphabet = grpSongs.members[i];
			item.targetY = i - curSelected;
			var scaledY:Float = FlxMath.remapToRange(item.targetY, 0, 1, 0, 1.3);
			item.y = FlxMath.lerp(item.y, (scaledY * 90) + (FlxG.height * 0.45), 0.16 / (ClientPrefs.data.framerate / 60));
			item.x = FlxMath.lerp(item.x, Math.exp(scaledY * 0.8) * -70 + (FlxG.width * 0.35), 0.16 / (ClientPrefs.data.framerate / 60));
			item.alpha = item.targetY == 0 ? 1 : 0.6;
		}

		if (!substated && selectable)
		{
			if (songs.length > 0)
			{
				if (controls.UI_UP_P)
					changeSelection(-1);
				if (controls.UI_DOWN_P)
					changeSelection(1);
			}

			if (controls.BACK)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'), 100);
				MusicBeatState.switchState(new PlaySelectionState());
				return;
			}

			if (controls.ACCEPT && songs.length > 0)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'), 100);
				Endless_Substate.song = songs[curSelected].songName.toLowerCase();
				Endless_Substate.songFolder = songs[curSelected].folder;
				substated = true;
				openSubState(new Endless_Substate());
			}
		}

		if (no)
		{
			bg.visible = false;
			checker.visible = false;
			side.visible = false;
			scoreText.visible = false;
			grpSongs.visible = false;
		}
	}

	function changeSelection(change:Int = 0):Void
	{
		if (songs.length == 0)
		{
			curSelected = 0;
			scoreText.text = 'PERSONAL BEST:\n0';
			return;
		}

		if (change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'), 100);

		curSelected += change;
		if (curSelected < 0)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = 0;

		var score:Int = 0;
		#if !switch
		score = Highscore.getEndless(songs[curSelected].songName.toLowerCase(), songs[curSelected].folder);
		#end
		scoreText.text = 'PERSONAL BEST:\n' + score;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Choosing ' + songs[curSelected].songName + ' for Endless', null);
		#end
	}

	function weekIsLocked(name:String):Bool
	{
		var week:WeekData = WeekData.weeksLoaded.get(name);
		return week != null && !week.startUnlocked && week.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(week.weekBefore) || !StoryMenuState.weekCompleted.get(week.weekBefore));
	}

	override function destroy()
	{
		songs = [];
		super.destroy();
	}
}

class SongTitlesE
{
	public var songName:String;
	public var folder:String;

	public function new(song:String, folder:String)
	{
		songName = song;
		this.folder = folder;
	}
}
