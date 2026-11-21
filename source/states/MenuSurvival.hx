package states;

import haxe.Json;
import backend.Mods;
import backend.WeekData;
import backend.Highscore;
import backend.Song;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import sys.io.File;
import flixel.util.FlxTimer;
import sys.FileSystem;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxGradient;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxG;
import flixel.addons.display.FlxBackdrop;
import flixel.FlxSprite;
import substates.Survival_GameOptions;
import substates.Survival_Substate;

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

	var bg:FlxSprite = new FlxSprite(-89).loadGraphic(Paths.image('MicUp/sBG_Main'));
	var checker:FlxBackdrop = new FlxBackdrop(Paths.image('MicUp/Survival_Checker'), flixel.util.FlxAxes.XY);
	var gradientBar:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, 300, 0xFFAA00AA);
	var side:FlxSprite = new FlxSprite(0).loadGraphic(Paths.image('MicUp/Survival_Side'));

    public static var curSelected:Int = 0;

	public var targetY:Float = 0;
	public var targetX:Float = 0;
	var camLerp:Float = 0.1;
	var selectable:Bool = false;

    var songs:Array<SongTitlesS> = [];

	public static var curDifficulty:Int = 2;

    private var grpSongs:FlxTypedGroup<Alphabet>;
	var sprDifficulty:FlxSprite;

	public static var substated:Bool = false;
	public static var no:Bool = false;

	var tracksUsed:FlxText;

    override function create()
    {
		substated = false;
		no = false;

		PlayState.isStoryMode = false;
		PlayState.isEndless = false;
		PlayState.isMarathon = false;
		PlayState.isFreeplay = false;
		PlayState.isSurvival = true;

        lime.app.Application.current.window.title = lime.app.Application.current.meta.get('name');

		Mods.loadTopMod();
		loadCurrent();
		Survival_GameOptions.load();

		PlayState.timeLeftOver = 0;

        persistentUpdate = persistentDraw = true;

		WeekData.reloadWeekFiles(false);
		for (weekName in WeekData.weeksList)
		{
			var week:WeekData = WeekData.weeksLoaded.get(weekName);
			if (week == null || weekIsLocked(weekName))
				continue;

			WeekData.setDirectoryFromWeek(week);
			for (song in week.songs)
			{
				var folder:String = Mods.currentModDirectory;
				songs.push(new SongTitlesS(song[0], folder != null ? folder : ''));
			}
		}
		Mods.loadTopMod();
		var legacySongListPath:String = Paths.txt('freeplaySonglist');
		var legacySongFolder:String = Paths.getModFolderNameFromPath(legacySongListPath);
		if (legacySongFolder == null)
			legacySongFolder = '';
		for (entry in CoolUtil.coolTextFile(legacySongListPath))
		{
			var data:Array<String> = entry.split(':');
			if (data.length == 0 || data[0] == null || data[0].trim().length == 0)
				continue;
			var songName:String = data[0];
			var folder:String = legacySongFolder;
			var alreadyListed:Bool = false;
			for (song in songs)
			{
				if (song.folder == folder && Paths.formatToSongPath(song.songName) == Paths.formatToSongPath(songName))
				{
					alreadyListed = true;
					break;
				}
			}
			if (!alreadyListed)
				songs.push(new SongTitlesS(songName, folder));
		}

		bg.scrollFactor.x = 0;
		bg.scrollFactor.y = 0.03;
		bg.setGraphicSize(Std.int(bg.width * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = true;
		add(bg);

		gradientBar = FlxGradient.createGradientFlxSprite(Math.round(FlxG.width), 512, [0x00ff0000, 0x55FFCAA9, 0xAAFFDBF6], 1, 90, true);
		gradientBar.y = FlxG.height - gradientBar.height;
		add(gradientBar);
		gradientBar.scrollFactor.set(0, 0);

		add(checker);
		checker.scrollFactor.set(0.07, 0.07);
		checker.velocity.set(0.2, 0.2);

		side.scrollFactor.x = 0;
		side.scrollFactor.y = 0;
		side.x = -20 - side.width;
		side.antialiasing = true;
		add(side);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var songLabel:String = songs[i].songName;
			if (songs[i].folder.length > 0 && songs[i].folder != Mods.BASE_GAME_MOD_FOLDER)
				songLabel += ' [' + songs[i].folder + ']';
			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, songLabel, true);
			// songText.itemType = "Vertical";
			songText.targetY = i;
			songText.targetX = -45;
			grpSongs.add(songText);

			// songText.x += 40;
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
			// songText.screenCenter(X);
		}

		FlxTween.tween(bg, {alpha: 1}, 0.8, {ease: FlxEase.quartInOut});
		FlxTween.tween(side, {x: 0}, 0.8, {ease: FlxEase.quartInOut});
		FlxG.camera.zoom = 0.6;
		FlxG.camera.alpha = 0;
		FlxTween.tween(FlxG.camera, {zoom: 1, alpha: 1}, 0.7, {ease: FlxEase.quartInOut});

		tracksUsed = new FlxText(FlxG.width * 0.7, 635, 0, "0 TRACKS USED\nPERSONAL BEST", 20);
		tracksUsed.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		tracksUsed.setBorderStyle(OUTLINE, 0xFF000000, 5, 1);
		add(tracksUsed);

		var diffTex = Paths.getSparrowAtlas('difficulties');
		sprDifficulty = new FlxSprite(130, 0);
		sprDifficulty.frames = diffTex;
		sprDifficulty.animation.addByPrefix('noob', 'NOOB');
		sprDifficulty.animation.addByPrefix('easy', 'EASY');
		sprDifficulty.animation.addByPrefix('normal', 'NORMAL');
		sprDifficulty.animation.addByPrefix('hard', 'HARD');
		sprDifficulty.animation.addByPrefix('expert', 'EXPERT');
		sprDifficulty.animation.addByPrefix('insane', 'INSANE');
		sprDifficulty.animation.play('easy');
		sprDifficulty.x = 1240 - sprDifficulty.width;
		sprDifficulty.y = tracksUsed.y - sprDifficulty.height - 8;
		add(sprDifficulty);

		changeSelection();
		changeDiff();

		new FlxTimer().start(0.7, function(tmr:FlxTimer)
		{
			selectable = true;
		});

		super.create();

		DiscordClient.changePresence("Choosing my survival adventure.", null);
    }

	var score = Std.int(FlxG.save.data.survivalScore);
	var minutes = Std.int(FlxG.save.data.survivalTime / 1000 / 60);
	var seconds = Std.int((FlxG.save.data.survivalTime / 1000) % 60);
	var milliseconds = Std.int((FlxG.save.data.survivalTime / 10) % 100);

    override function update(elapsed:Float)
    {
        checker.x -= -0.67 / (ClientPrefs.data.framerate/60);
		checker.y -= 0.2 / (ClientPrefs.data.framerate/60);

		tracksUsed.text = PlayState.storyPlaylist.length + '/5 TRACKS USED\nPERSONAL BEST: $minutes:$seconds:$milliseconds - $score';
		tracksUsed.x = 1240 - tracksUsed.width;

        super.update(elapsed);

		var bullShit:Int = 0;

		for (item in grpSongs.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

				var scaledY = FlxMath.remapToRange(item.targetY, 0, 1, 0, 1.3);

				item.y = FlxMath.lerp(item.y, (scaledY * 120) + (FlxG.height * 0.5), 0.16/(ClientPrefs.data.framerate / 60));
				item.x = FlxMath.lerp(item.x, (targetY * 0) + 308, 0.16/(ClientPrefs.data.framerate / 60));
				item.x += -45/(ClientPrefs.data.framerate / 60);
		}

        var upP = controls.UI_UP_P;
		var downP = controls.UI_DOWN_P;
		var accepted = controls.ACCEPT;
		var back = controls.BACK;

		if (selectable && !substated)
		{
			if (upP)
				changeSelection(-1);
			if (downP)
				changeSelection(1);

			if (controls.UI_LEFT_P)
				changeDiff(-1);
			if (controls.UI_RIGHT_P)
				changeDiff(1);

			if (back)
				{
					substated = true;
	
					FlxG.sound.play(Paths.sound('cancelMenu'), 100);
	
					FlxG.state.openSubState(new Survival_Substate());
				}

			if (accepted)
				{
					if (PlayState.difficultyPlaylist.length < 5)
					{
						PlayState.difficultyPlaylist.push(Std.string(curDifficulty));
						PlayState.storyPlaylist.push(Std.string(songs[curSelected].songName.toLowerCase()));
						PlayState.storyFolderPlaylist.push(songs[curSelected].folder);
		
						FlxG.sound.play(Paths.sound('confirmMenu'), 100);
		
						saveCurrent();
					}
					else
						FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
				}
		}

		if (no)
			{
				bg.kill();
				gradientBar.kill();
				checker.kill();
				sprDifficulty.kill();
				grpSongs.clear();
				tracksUsed.kill();
				side.kill();
			}
    }

    function changeDiff(change:Int = 0)
        {
            curDifficulty += change;
    
            if (curDifficulty < 0)
                curDifficulty = 5;
            if (curDifficulty > 5)
                curDifficulty = 0;
    
            switch (curDifficulty)
            {
                case 0:
                    sprDifficulty.animation.play('noob');
                case 1:
                    sprDifficulty.animation.play('easy');
                case 2:
                    sprDifficulty.animation.play('normal');
                case 3:
                    sprDifficulty.animation.play('hard');
                case 4:
                    sprDifficulty.animation.play('expert');
                case 5:
                    sprDifficulty.animation.play('insane');
            }
    
            sprDifficulty.alpha = 0;
    
            sprDifficulty.y = tracksUsed.y - sprDifficulty.height - 38;
            FlxTween.tween(sprDifficulty, {y: tracksUsed.y - sprDifficulty.height - 8, alpha: 1}, 0.04);
            sprDifficulty.x = 1240 - sprDifficulty.width;
        }
    
	function weekIsLocked(name:String):Bool
	{
		var week:WeekData = WeekData.weeksLoaded.get(name);
		return !week.startUnlocked && week.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(week.weekBefore) || !StoryMenuState.weekCompleted.get(week.weekBefore));
	}

    function changeSelection(change:Int = 0)
    {
        // NGio.logEvent('Fresh');
        FlxG.sound.play(Paths.sound('scrollMenu'), 100);
    
        curSelected += change;
    
        if (curSelected < 0)
            curSelected = songs.length - 1;
        if (curSelected >= songs.length)
            curSelected = 0;
    
        var bullShit:Int = 0;
    
        for (item in grpSongs.members)
        {
            item.targetY = bullShit - curSelected;
            bullShit++;
    
            item.alpha = 0.6;
            // item.setGraphicSize(Std.int(item.width * 0.8));
    
        if (item.targetY == 0)
            {
                item.alpha = 1;
                // item.setGraphicSize(Std.int(item.width));
            }
        }
    }

	function loadCurrent()
		{
			if (!FileSystem.isDirectory('presets/survival'))
				FileSystem.createDirectory('presets/survival');
	
			if (!FileSystem.exists('presets/survival/current'))
			{
				_survival = {
					songDifficulties: [],
					songNames: [],
					songFolders: []
				}

				PlayState.difficultyPlaylist = [];
				PlayState.storyPlaylist = [];
				PlayState.storyFolderPlaylist = [];
				File.saveContent(('presets/survival/current'), Json.stringify(_survival, null, '    '));
			}
			else
			{
				var data:String = File.getContent('presets/survival/current');
				_survival = Json.parse(data);
				PlayState.difficultyPlaylist = _survival.songDifficulties;
				PlayState.storyPlaylist = _survival.songNames;
				restoreSongFolders(_survival.songFolders);
			}
		}
	
	public static function saveCurrent()
		{
			_survival = {
				songDifficulties: PlayState.difficultyPlaylist,
				songNames: PlayState.storyPlaylist,
				songFolders: PlayState.storyFolderPlaylist
			}
			File.saveContent(('presets/survival/current'), Json.stringify(_survival, null, '    '));
		}
	
	public static function loadPreset(input:String):Void
		{
			var data:String = File.getContent('presets/survival/' + input);
			_survival = Json.parse(data);
	
			PlayState.difficultyPlaylist = _survival.songDifficulties;
			PlayState.storyPlaylist = _survival.songNames;
			restoreSongFolders(_survival.songFolders);
	
			saveCurrent();
		}
	
	public static function savePreset(input:String):Void
		{
			_survival = {
				songDifficulties: PlayState.difficultyPlaylist,
				songNames: PlayState.storyPlaylist,
				songFolders: PlayState.storyFolderPlaylist
			}
			File.saveContent(('presets/survival/' + input), Json.stringify(_survival, null, '    ')); // just an example for now
		}

		static function restoreSongFolders(folders:Array<String>):Void
		{
			PlayState.storyFolderPlaylist = folders != null ? folders.copy() : [];
			var fallback:String = Mods.currentModDirectory != null ? Mods.currentModDirectory : '';
			while (PlayState.storyFolderPlaylist.length < PlayState.storyPlaylist.length)
				PlayState.storyFolderPlaylist.push(fallback);
			while (PlayState.storyFolderPlaylist.length > PlayState.storyPlaylist.length)
				PlayState.storyFolderPlaylist.pop();
			for (i in 0...PlayState.storyFolderPlaylist.length)
				if (PlayState.storyFolderPlaylist[i] == null)
					PlayState.storyFolderPlaylist[i] = fallback;
		}
}

class SongTitlesS
{
	public var songName:String = "";
		public var folder:String = "";

		public function new(song:String, folder:String)
	{
		this.songName = song;
			this.folder = folder;
	}
}