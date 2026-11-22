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
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
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
	var lerpSelected:Float = 0;
	var _drawDistance:Int = 4;

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
		PlayState.loops = 0;
		PlayState.campaignScore = 0;
		PlayState.campaignMisses = 0;
		PlayState.campaignMaxCombo = 0;
		PlayState.campaignAccuracySum = 0;
		PlayState.campaignSongsCount = 0;
		PlayState.endlessCombo = 0;
		PlayState.endlessTotalPlayed = 0;
		PlayState.endlessTotalNotesHit = 0;
		PlayState.endlessTotalNotes = 0;
		PlayState.endlessBonusLimit = backend.AccuracyTools.BONUS_MAX;

		buildSongList();
		if (curSelected < 0 || curSelected >= songs.length)
			curSelected = 0;

		bg = new FlxSprite().loadGraphic(Paths.image('MicUp/EndBG_Main'));
		bg.scrollFactor.set(0,0.03);
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
		side.screenCenter(Y);
		side.x = 500 - side.width;
		FlxTween.tween(side, {x: 0}, 0.6, {ease: FlxEase.quartInOut});

		FlxTween.tween(bg, {alpha: 1}, 0.8, {ease: FlxEase.quartInOut});
		FlxG.camera.zoom = 0.6;
		FlxG.camera.alpha = 1;
		FlxTween.tween(FlxG.camera, {zoom: 1}, 0.7, {ease: FlxEase.quartInOut});

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var label:String = songs[i].songName;
			if (songs[i].folder.length > 0 && songs[i].folder != Mods.BASE_GAME_MOD_FOLDER)
				label += ' [' + songs[i].folder + ']';

			var songText:Alphabet = new Alphabet(0, 50 + (90 * i), label, true);
			//songText.itemType = 'D-Shape';
			songText.targetY = i;
			songText.visible = songText.active = songText.isMenuItem = false;

			Mods.currentModDirectory = songs[i].folder;
			grpSongs.add(songText);
		}
		Mods.loadTopMod();
		lerpSelected = curSelected;

		scoreText = new FlxText(10, 5, FlxG.width - 20, 'PERSONAL BEST:\n0', 32);
		scoreText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, LEFT);
		scoreText.setBorderStyle(OUTLINE, FlxColor.BLACK, 5, 1);
		scoreText.screenCenter(Y);
		scoreText.x = 10;
		add(scoreText);

		FlxTween.tween(scoreText, {alpha: 1}, 0.5, {ease: FlxEase.quartInOut});

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
				songs.push(new SongTitlesE(song[0], Mods.currentModDirectory != null ? Mods.currentModDirectory : '', week.difficulties));
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
				songs.push(new SongTitlesE(songName, legacyFolder, ''));
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		checker.x -= 0.27 / (ClientPrefs.data.framerate / 60);
		checker.y -= -0.2 / (ClientPrefs.data.framerate / 60);

		lerpSelected = FlxMath.lerp(lerpSelected, curSelected, FlxMath.bound(elapsed * 9.6, 0, 1));

		for (i in 0...grpSongs.members.length)
		{
			var item:Alphabet = grpSongs.members[i];
			var offset:Float = i - lerpSelected;
			var scaledY:Float = offset * 1.3;
			var visible:Bool = Math.abs(offset) <= _drawDistance;
			item.visible = item.active = visible;
			item.targetY = i - curSelected;
			item.alpha = i == curSelected ? 1 : 0.6;

			if (visible)
			{
				var targetX:Float = FlxG.width + 30;
				if (scaledY >= 0 && scaledY < 10)
					targetX = Math.exp(scaledY * 0.8) * 70 + FlxG.width * 0.1;
				else if (scaledY < 0 && scaledY > -20)
					targetX = Math.exp(scaledY * -0.8) * 70 + FlxG.width * 0.1;

				var targetY:Float = scaledY * 65 + FlxG.height * 0.39;
				var lerpAmount:Float = FlxMath.bound(elapsed * 9.6, 0, 1);
				item.x = FlxMath.lerp(item.x, Math.min(targetX, FlxG.width + 30), lerpAmount);
				item.y = FlxMath.lerp(item.y, targetY, lerpAmount);
			}
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
				FlxTween.tween(FlxG.camera, {zoom: 0.6, alpha: -0.6}, 0.7, {ease: FlxEase.quartInOut});
				FlxTween.tween(bg, {alpha: 0}, 0.7, {ease: FlxEase.quartInOut});
				FlxTween.tween(checker, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
				FlxTween.tween(gradientBar, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
				FlxTween.tween(side, {x: -500 - side.width}, 0.3, {ease: FlxEase.quartInOut});
				FlxTween.tween(scoreText, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
				return;
			}

			if (controls.ACCEPT && songs.length > 0)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'), 100);
				Endless_Substate.song = songs[curSelected].songName.toLowerCase();
				Endless_Substate.songFolder = songs[curSelected].folder;
				Endless_Substate.difficulties = songs[curSelected].difficulties;
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
	public var difficulties:String;

	public function new(song:String, folder:String, difficulties:String)
	{
		songName = song;
		this.folder = folder;
		this.difficulties = difficulties != null ? difficulties : '';
	}
}
