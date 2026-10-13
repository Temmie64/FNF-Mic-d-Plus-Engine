package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import backend.SongChecker;
import backend.SongChecker.SongCheckReport;
import backend.SongChecker.SongCheckSeverity;
import backend.SongLoadMetrics;
import haxe.Timer;
import backend.AccuracyTools;
import objects.HealthIcon;
import objects.MusicPlayerPsych;
import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;
import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;
import openfl.utils.Assets;
#if (MODS_ALLOWED && sys)
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
#end
import haxe.Json;

class FreeplayState_Psych extends MusicBeatState
{
	var songs:Array<SongMetadataPsych> = [];

	var selector:FlxText;

	private static var curSelected:Int = 0;

	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;

	private static var lastDifficultyName:String = Difficulty.getDefault();

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	var bg:FlxSprite;
	var checker:FlxBackdrop = new FlxBackdrop(Paths.image('MicUp/Free_Checker'), flixel.util.FlxAxes.XY);
	var gradientBar:FlxSprite = FlxGradient.createGradientFlxSprite(Math.round(FlxG.width),512, [0x00ff0000, 0x55FFBDF8, 0xAAFFFDF3], 1, 90, true);
	var side:FlxSprite = new FlxSprite(0).loadGraphic(Paths.image('MicUp/Free_Bottom'));
	var navi:FlxSprite = new FlxSprite(0).loadGraphic(Paths.image('MicUp/navi_Free'));
	var intendedColor:Int;
	var intendedColor2:Int;
	var intendedColor3:Int;
	var intendedColor4:Int;
	var intendedColor5:Int;
	var colorTween:FlxTween;
	var colorTween2:FlxTween;
	var colorTween3:FlxTween;
	var colorTween4:FlxTween;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var disc:FlxSprite = new FlxSprite(-200, 730);

	var innerDiscTop:FlxSprite = new FlxSprite(-200, 730);
	var innerDiscBottom:FlxSprite = new FlxSprite(-200, 730);

	var discIcon:HealthIcon = new HealthIcon("bf");

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var player:MusicPlayerPsych;
	var freeplayTouchInputBlockTime:Float = 0;

	override function create()
	{
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		final accept:String = (controls.mobileC) ? "A" : "ACCEPT";
		final reject:String = (controls.mobileC) ? "B" : "BACK";

		if (WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress " + accept + " to go to the Week Editor Menu.\nPress "
				+ reject + " to return to Main Menu.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())));
			return;
		}

		for (i in 0...WeekData.weeksList.length)
		{
			if (weekIsLocked(WeekData.weeksList[i]))
				continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var leSongs:Array<String> = [];
			var leChars:Array<String> = [];

			for (j in 0...leWeek.songs.length)
			{
				leSongs.push(leWeek.songs[j][0]);
				leChars.push(leWeek.songs[j][1]);
			}

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				var colorsChecker:Array<Int> = song[3];
				var colorsBottom:Array<Int> = song[4];
				var colorsDiscTop:Array<Int> = song[5];
				var colorsDiscBottom:Array<Int> = song[6];
				if(colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}

				if(colorsChecker == null || colorsChecker.length < 3)
				{
					colorsChecker = [0, 0, 0];
				}

				if(colorsBottom == null || colorsBottom.length < 3)
				{
					colorsBottom = [0, 0, 0];
				}

				if(colorsDiscTop == null || colorsDiscTop.length < 3)
				{
					colorsDiscTop = [0, 0, 0];
				}

				if(colorsDiscBottom == null || colorsDiscBottom.length < 3)
				{
					colorsDiscBottom = [0, 0, 0];
				}
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]), FlxColor.fromRGB(colorsChecker[0], colorsChecker[1], colorsChecker[2]), FlxColor.fromRGB(colorsBottom[0], colorsBottom[1], colorsBottom[2]), FlxColor.fromRGB(colorsDiscTop[0], colorsDiscTop[1], colorsDiscTop[2]), FlxColor.fromRGB(colorsDiscBottom[0], colorsDiscBottom[1], colorsDiscBottom[2]));
			}
		}
		Mods.loadTopMod();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();

		gradientBar.y = FlxG.height - gradientBar.height;
		add(gradientBar);
		gradientBar.scrollFactor.set(0, 0);

		add(checker);
		checker.scrollFactor.set(0, 0.07);

		side.scrollFactor.x = 0;
		side.scrollFactor.y = 0;
		side.antialiasing = true;
		side.screenCenter();
		add(side);
		side.y = FlxG.height;
		// side.y = FlxG.height - side.height/3*2;
		side.x = FlxG.width / 2 - side.width / 2;

		navi.scrollFactor.x = 0;
		navi.scrollFactor.y = 0;
		navi.antialiasing = true;
		navi.screenCenter();
		add(navi);
		navi.y = FlxG.height / 1.25;
		// navi.y = FlxG.height - navi.height/3*2;
		navi.x = FlxG.width / 1.05 - navi.width / 2;

		var tex = Paths.getSparrowAtlas('MicUp/Freeplay_Discs');
		disc.frames = tex;
		disc.animation.addByPrefix("spin", "spin", 24);
		disc.animation.play("spin");
		add(disc);

		innerDiscTop = new FlxSprite().loadGraphic(Paths.image('MicUp/innerDiscTop'));
		innerDiscTop.antialiasing = ClientPrefs.data.antialiasing;
		add(innerDiscTop);

		innerDiscBottom = new FlxSprite().loadGraphic(Paths.image('MicUp/innerDiscBottom'));
		innerDiscBottom.antialiasing = ClientPrefs.data.antialiasing;
		add(innerDiscBottom);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.targetY = i;
			grpSongs.add(songText);

			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();

			Mods.currentModDirectory = songs[i].folder;
			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;

			songText.visible = songText.active = songText.isMenuItem = false;
			icon.visible = icon.active = false;

			iconArray.push(icon);
			add(icon);
		}

		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		scoreText.alignment = CENTER;
		scoreText.setBorderStyle(OUTLINE, 0xFF000000, 5, 1);
		scoreText.screenCenter(X);
		scoreText.y = sprDifficulty.y - 38;
		add(scoreText);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0; // 0.6
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 130, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);

		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);		

		if(curSelected >= songs.length) curSelected = 0;
		bg.color = songs[curSelected].color;
		checker.color = songs[curSelected].checkerColor;
		innerDiscTop.color = songs[curSelected].discTopColor;
		innerDiscBottom.color = songs[curSelected].discBottomColor;
		side.color = songs[curSelected].bottomColor;
		intendedColor = bg.color;
		intendedColor2 = checker.color;
		intendedColor3 = side.color;
		intendedColor4 = innerDiscTop.color;
		intendedColor5 = innerDiscBottom.color;
		lerpSelected = curSelected;

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		textBG.alpha = 0.6;
		add(textBG);
		textBG.visible = false;

		final space:String = (controls.mobileC) ? "X" : "SPACE";
		final control:String = (controls.mobileC) ? "C" : "CTRL";
		final reset:String = (controls.mobileC) ? "Y" : "RESET";

		var leText:String = Language.getPhrase("freeplay_tip",
			"Press {1} to listen to the Song / Press {2} to open the Gameplay Changers Menu / Press {3} to Reset your Score and Accuracy.",
			[space, control, reset]);
		#if (MODS_ALLOWED && sys && !mobile)
		leText += " / F5 reloads mods / drop a mod folder to import it.";
		#end
		bottomString = leText;

		var size:Int = 16;
		bottomText = new FlxText(5, 0, FlxG.width - 10, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.wordWrap = true;
		bottomText.alignment = CENTER;
		bottomText.scrollFactor.set();

		var padding:Int = 8;
		bottomBG = new FlxSprite(0, 0).makeGraphic(FlxG.width, Std.int(bottomText.height + padding), 0xFF000000);
		bottomBG.alpha = 0.6;
		bottomBG.y = FlxG.height - bottomBG.height;
		bottomText.y = bottomBG.y + (bottomBG.height - bottomText.height) / 2;
		add(bottomBG);
		add(bottomText);

		player = new MusicPlayerPsych(this);
		add(player);

		changeSelection();
		updateTexts();

		addTouchPad('LEFT_FULL', 'A_B_C_X_Y_Z');
		addTouchPadCamera();
		if (touchPad != null)
			touchPad.updateTrackedButtons();
		freeplayTouchInputBlockTime = 0.12;
		super.create();

		disc.scale.x = 0;
		FlxTween.tween(disc, {'scale.x': 1, y: 480, x: -25}, 0.5, {ease: FlxEase.quartInOut});

		innerDiscTop.scale.x = 0;
		FlxTween.tween(innerDiscTop, {'scale.x': 1, y: 480, x: -25}, 0.5, {ease: FlxEase.quartInOut});

		innerDiscBottom.scale.x = 0;
		FlxTween.tween(innerDiscBottom, {'scale.x': 1, y: 480, x: -25}, 0.5, {ease: FlxEase.quartInOut});

		FlxTween.tween(scoreText, {alpha: 1}, 0.5, {ease: FlxEase.quartInOut});
		FlxTween.tween(sprDifficulty, {alpha: 1}, 0.5, {ease: FlxEase.quartInOut});
		FlxTween.tween(side, {y: FlxG.height - side.height / 3 * 2}, 0.5, {ease: FlxEase.quartInOut});

		FlxG.camera.zoom = 0.6;
		FlxG.camera.alpha = 0;
		FlxTween.tween(FlxG.camera, {zoom: 1, alpha: 1}, 0.5, {ease: FlxEase.quartInOut});

		#if (MODS_ALLOWED && sys && !mobile)
		FlxG.stage.window.onDropFile.add(onDropFile);
		#end
	}

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
		removeTouchPad();
		addTouchPad('LEFT_FULL', 'A_B_C_X_Y_Z');
		addTouchPadCamera();
		if (touchPad != null)
			touchPad.updateTrackedButtons();
		freeplayTouchInputBlockTime = 0.12;
	}

	inline function touchActionReleased(button:Dynamic):Bool
	{
		return freeplayTouchInputBlockTime <= 0 && button != null && button.justReleased;
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		songs.push(new SongMetadataPsych(songName, weekNum, songCharacter, color));
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked
			&& leWeek.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	var instPlaying:Int = -1;

	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;

	var holdTime:Float = 0;

	var stopMusicPlay:Bool = false;

	override function update(elapsed:Float)
	{
		if (freeplayTouchInputBlockTime > 0)
			freeplayTouchInputBlockTime -= elapsed;

		if (songs.length < 1)
			return;

		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var shiftMult:Int = 1;
		if ((FlxG.keys.pressed.SHIFT || touchPad.buttonZ.justPressed) && !player.playingMusic)
			shiftMult = 3;

		if (!player.playingMusic)
		{
			#if (MODS_ALLOWED && sys && !mobile)
			if (FlxG.keys.justPressed.F5)
			{
				reloadModsFromFreeplay();
				return;
			}
			#end

			scoreText.text = 'PERSONAL BEST: ${lerpScore} (${AccuracyTools.format(lerpRating)})';
			positionHighscore();

			if (songs.length > 1)
			{
				if (FlxG.keys.justPressed.HOME)
				{
					curSelected = 0;
					changeSelection();
					holdTime = 0;
				}
				else if (FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection();
					holdTime = 0;
				}
				if (controls.UI_UP_P || touchPad.buttonUp.justPressed)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P || touchPad.buttonDown.justPressed)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if (controls.UI_DOWN || controls.UI_UP || touchPad.buttonUp.pressed || touchPad.buttonDown.pressed)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * ((controls.UI_UP || touchPad.buttonUp.pressed) ? -shiftMult : shiftMult));
				}

				if (FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
			}

			if (controls.UI_LEFT_P || touchPad.buttonLeft.justPressed)
			{
				changeDiff(-1);
				_updateSongLastDifficulty();
			}
			else if (controls.UI_RIGHT_P || touchPad.buttonRight.justPressed)
			{
				changeDiff(1);
				_updateSongLastDifficulty();
			}
		}

		if (controls.BACK || touchPad.buttonB.justPressed #if android || FlxG.android.justReleased.BACK #end)
		{
			if (player.playingMusic)
			{
				FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				instPlaying = -1;

				player.playingMusic = false;
				player.switchPlayMusic();

				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
			}
			else
			{
				persistentUpdate = false;
				if(colorTween != null) {
					colorTween.cancel();
					colorTween2.cancel();
					colorTween3.cancel();
				}
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new PlaySelectionState());
				FlxTween.tween(FlxG.camera, {zoom: 0.6, alpha: -0.6}, 0.7, {ease: FlxEase.quartInOut});
				FlxTween.tween(bg, {alpha: 0}, 0.7, {ease: FlxEase.quartInOut});
				FlxTween.tween(checker, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
				FlxTween.tween(gradientBar, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
				FlxTween.tween(side, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
				FlxTween.tween(sprDifficulty, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
				FlxTween.tween(scoreText, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
				FlxTween.tween(disc, {alpha: 0, 'scale.x': 0}, 0.3, {ease: FlxEase.quartInOut});
				FlxTween.tween(innerDiscTop, {alpha: 0, 'scale.x': 0}, 0.3, {ease: FlxEase.quartInOut});
				FlxTween.tween(innerDiscBottom, {alpha: 0, 'scale.x': 0}, 0.3, {ease: FlxEase.quartInOut});
			}
		}

		if ((FlxG.keys.justPressed.CONTROL || touchPad.buttonC.justPressed) && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(backend.ScriptableSubstate.tryCreate('options.GameplayChangersSubstate', new GameplayChangersSubstate()));
			removeTouchPad();
		}
		else if (FlxG.keys.justPressed.SPACE || touchPad.buttonX.justPressed)
		{
			if (instPlaying != curSelected && !player.playingMusic)
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				Mods.currentModDirectory = songs[curSelected].folder;
				var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
				if (!loadChartWithChecker(poop, songs[curSelected].songName.toLowerCase()))
				{
					updateTexts(elapsed);
					super.update(elapsed);
					return;
				}
				if (PlayState.SONG.needsVoices)
				{
					vocals = new FlxSound();
					try
					{
						var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
						if (loadedVocals == null)
							loadedVocals = Paths.voices(PlayState.SONG.song);

						if (loadedVocals != null && loadedVocals.length > 0)
						{
							vocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(vocals);
							vocals.persist = vocals.looped = true;
							vocals.volume = 0.8;
							vocals.play();
							vocals.pause();
						}
						else
							vocals = FlxDestroyUtil.destroy(vocals);
					}
					catch (e:Dynamic)
					{
						vocals = FlxDestroyUtil.destroy(vocals);
					}

					opponentVocals = new FlxSound();
					try
					{
						var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');

						if (loadedVocals != null && loadedVocals.length > 0)
						{
							opponentVocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(opponentVocals);
							opponentVocals.persist = opponentVocals.looped = true;
							opponentVocals.volume = 0.8;
							opponentVocals.play();
							opponentVocals.pause();
						}
						else
							opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
					catch (e:Dynamic)
					{
						opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
				}

				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
				FlxG.sound.music.pause();
				instPlaying = curSelected;

				player.playingMusic = true;
				player.curTime = 0;
				player.switchPlayMusic();
				player.pauseOrResume(true);
			}
			else if (instPlaying == curSelected && player.playingMusic)
			{
				player.pauseOrResume(!player.playing);
			}
		}
		else if ((controls.ACCEPT || touchPad.buttonA.justPressed) && !player.playingMusic)
		{
			persistentUpdate = false;

			var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
			var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

			if (!loadChartWithChecker(poop, songLowercase))
			{
				persistentUpdate = true;
				updateTexts(elapsed);
				super.update(elapsed);
				return;

				FlxTween.tween(bg, {alpha: 0}, 0.6, {ease: FlxEase.quartInOut});
				FlxTween.tween(checker, {alpha: 0}, 0.6, {ease: FlxEase.quartInOut});
				FlxTween.tween(gradientBar, {alpha: 0}, 0.6, {ease: FlxEase.quartInOut});
				FlxTween.tween(side, {alpha: 0}, 0.8, {ease: FlxEase.quartInOut});
				FlxTween.tween(disc, {alpha: 0, 'scale.x': 0}, 0.8, {ease: FlxEase.quartInOut});
				FlxTween.tween(innerDiscTop, {alpha: 0, 'scale.x': 0}, 0.8, {ease: FlxEase.quartInOut});
				FlxTween.tween(innerDiscBottom, {alpha: 0, 'scale.x': 0}, 0.8, {ease: FlxEase.quartInOut});
				FlxTween.tween(scoreText, {y: 750, alpha: 0}, 0.8, {ease: FlxEase.quartInOut});
				FlxTween.tween(navi, {alpha: 0}, 0.8, {ease: FlxEase.quartInOut});
				FlxTween.tween(sprDifficulty, {y: 750, alpha: 0}, 0.8, {ease: FlxEase.quartInOut});
				for (item in grpSongs.members)
				{
					FlxTween.tween(item, {alpha: 0}, 0.9, {ease: FlxEase.quartInOut});
				}
			}
			trace(poop);

			try
			{
				//PlayState.SONG = Song.loadFromJson(poop, songLowercase);
				//PlayState.isStoryMode = false;
				//PlayState.isEndless = false;
				//PlayState.isMarathon = false;
				//PlayState.isFreeplay = true;
				//PlayState.isSurvival = false;
				//PlayState.storyDifficulty = curDifficulty;

				trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
				if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
				{
					trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
					Paths.freeGraphicsFromMemory();
				}
				if(colorTween != null) {
					colorTween.cancel();
				colorTween2.cancel();
				colorTween3.cancel();
				}
			}

			/*PlayState.isStoryMode = false;
			PlayState.storyDifficulty = curDifficulty;
			trace('CURRENT WEEK: ' + WeekData.getWeekFileName());*/

			@:privateAccess
			if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
				Paths.freeGraphicsFromMemory();
			}
			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState());
			#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
			stopMusicPlay = true;

			destroyFreeplayVocals();
			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}
		else if ((controls.RESET || touchPad.buttonY.justPressed) && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			removeTouchPad();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		updateDisc();

		updateTexts(elapsed);
		super.update(elapsed);

		var bullShit:Int = 0;

		for (item in grpSongs.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

				var scaledY = FlxMath.remapToRange(item.targetY, 0, 1, 0, 1.3);

				item.y = FlxMath.lerp(item.y, (scaledY * 65) + (FlxG.height * 0.39), 0.16/(ClientPrefs.data.framerate / 60));

				item.visible = true;

				if (scaledY < 10)
				item.x = FlxMath.lerp(item.x, Math.exp(scaledY * 0.8) * 70 + (FlxG.width * 0.1), 0.16/(ClientPrefs.data.framerate / 60));

				if (scaledY < 0 && scaledY > -20)
					item.x = FlxMath.lerp(item.x, Math.exp(scaledY * -0.8) * 70 + (FlxG.width * 0.1), 0.16/(ClientPrefs.data.framerate / 60));
				if (item.x > FlxG.width + 30)
					item.x = FlxG.width + 30;
		}


		checker.x -= -0.27 / (ClientPrefs.data.framerate / 60);
		checker.y -= 0.63 / (ClientPrefs.data.framerate / 60);

		innerDiscBottom.x = disc.x + disc.width / 2 - innerDiscBottom.width / 2;
		innerDiscBottom.y = disc.y + disc.height / 2 - innerDiscBottom.height / 2;
		innerDiscBottom.angle = disc.angle;
		innerDiscBottom.scale.set(disc.scale.x, disc.scale.y);

		innerDiscTop.x = disc.x + disc.width / 2 - innerDiscTop.width / 2;
		innerDiscTop.y = disc.y + disc.height / 2 - innerDiscTop.height / 2;
		innerDiscTop.angle = disc.angle;
		innerDiscTop.scale.set(disc.scale.x, disc.scale.y);

		discIcon.x = disc.x + disc.width / 2 - discIcon.width / 2;
		discIcon.y = disc.y + disc.height / 2 - discIcon.height / 2;
		discIcon.angle = disc.angle += 0.6 / (ClientPrefs.data.framerate / 60);
		discIcon.scale.set(disc.scale.x, disc.scale.y);

	}

	function loadChartWithChecker(chartName:String, songFolder:String):Bool
	{
		var checkerStarted:Float = Timer.stamp();
		var report:SongCheckReport = SongChecker.inspectRequest(chartName, songFolder);
		if (!report.hasErrors)
		{
			try
			{
				var song = Song.loadFromJson(chartName, songFolder);
				SongChecker.inspectSong(report, song);
			}
			catch (e:Dynamic)
			{
				report.add(SongCheckSeverity.ERROR, 'chart-load-exception', 'Unexpected error while loading the chart: ${Std.string(e)}', report.chartPath);
			}
		}
		SongLoadMetrics.recordChecker((Timer.stamp() - checkerStarted) * 1000 - SongLoadMetrics.chartMs);

		if (report.hasErrors)
		{
			PlayState.SONG = null; // Never leak the previously selected chart into PlayState.
			missingText.text = report.displayText();
			missingText.screenCenter(Y);
			missingText.visible = true;
			missingTextBG.visible = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			trace(report.displayText(100));
			return false;
		}

		if (report.issues.length > 0)
			trace(report.displayText(100));
		return true;
	}

	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic)
		{
		}
		return null;
	}

	public static function destroyFreeplayVocals()
	{
		if (vocals != null)
			vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if (opponentVocals != null)
			opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic)
			return;

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length - 1);
		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		lastDifficultyName = Difficulty.getString(curDifficulty, false);
		var displayDiff:String = Difficulty.getString(curDifficulty);
		if (Difficulty.list.length > 1)
			diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
		else
			diffText.text = displayDiff.toUpperCase();

		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);
		_updateSongLastDifficulty();
		if (playSound)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		if (curSelected < 0)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = 0;

		var newColor:Int = songs[curSelected].color;
		var newCheckerColor:Int = songs[curSelected].checkerColor;
		var newBottomColor:Int = songs[curSelected].bottomColor;
		var newDiscTopColor:Int = songs[curSelected].discTopColor;
		var newDiscBottomColor:Int = songs[curSelected].discBottomColor;
		if (newColor != intendedColor)
		{
			if(colorTween != null) {
				colorTween.cancel();
				colorTween2.cancel();
				colorTween3.cancel();
			}
			intendedColor = newColor;
			intendedColor2 = newCheckerColor;
			intendedColor3 = newBottomColor;
			intendedColor4 = newDiscTopColor;
			intendedColor5 = newDiscBottomColor;

			innerDiscTop.color = intendedColor4;
			innerDiscBottom.color = intendedColor5;
			colorTween3 = FlxTween.color(checker, 0.5, checker.color, intendedColor2, {ease: FlxEase.backIn});
			colorTween2 = FlxTween.color(side, 0.5, side.color, intendedColor3, {ease: FlxEase.backIn});
			
			colorTween = FlxTween.color(bg, 0.5, bg.color, intendedColor, {ease: FlxEase.backIn});

				new FlxTimer().start(0.5, function(tmr:FlxTimer)
				{
					colorTween = null;
					colorTween2 = null;
					colorTween3 = null;
				});
			
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		for (num => item in grpSongs.members)
		{
			var icon:HealthIcon = iconArray[num];
			item.alpha = 0.6;
			icon.alpha = 0.6;
			if (item.targetY == curSelected)
			{
				item.alpha = 1;
				icon.alpha = 1;
			}
		}

		for (i in 0...iconArray.length)
		{
			iconArray[i].alpha = 0; // 0.6
			iconArray[i].animation.curAnim.curFrame = 0;

		}

		iconArray[curSelected].alpha = 0;
			iconArray[curSelected].animation.curAnim.curFrame = 2;

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

		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;
		Difficulty.loadFromWeek();

		var savedDiff:String = songs[curSelected].lastDifficulty;
		var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
		if (savedDiff != null && Difficulty.list.contains(savedDiff))
			curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(savedDiff)));
		else if (lastDiff > -1)
			curDifficulty = lastDiff;
		else if (Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		changeDiff();
		_updateSongLastDifficulty();
	}

	inline private function _updateSongLastDifficulty()
		songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);

	private function positionHighscore()
	{
		scoreText.x = FlxG.width / 2 - scoreText.width / 2;

		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);

		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];

	public function updateDisc()
{
		for (item in grpSongs.members) {
		remove(discIcon);
		discIcon = new HealthIcon(songs[curSelected].songCharacter);
		add(discIcon);
}
}

	public function updateTexts(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
		for (i in _lastVisibles)
		{
			grpSongs.members[i].visible = grpSongs.members[i].active = false;
			iconArray[i].visible = iconArray[i].active = false;
		}
		_lastVisibles = [];

		var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance)));
		for (i in min...max)
		{
			var item:Alphabet = grpSongs.members[i];
			item.visible = item.active = true;
			//item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
			//item.y = ((item.targetY - lerpSelected) * 1.3 * item.distancePerItem.y) + item.startPosition.y;

			for (item in grpSongs.members) {
				remove(discIcon);
				discIcon = new HealthIcon(songs[curSelected].songCharacter);
				add(discIcon);		
			}

			var icon:HealthIcon = iconArray[i];
			icon.visible = icon.active = true;
			_lastVisibles.push(i);
		}
	}

	#if (MODS_ALLOWED && sys && !mobile)
	function reloadModsFromFreeplay():Void
	{
		FlxG.sound.play(Paths.sound('scrollMenu'));
		WeekData.reloadWeekFiles(false);
		Mods.loadTopMod();
		persistentUpdate = false;
		MusicBeatState.switchState(FreeplayStateSelector.create());
	}

	function copyModFolderRecursive(source:String, target:String):Void
	{
		if (!FileSystem.exists(target))
			FileSystem.createDirectory(target);

		for (entry in FileSystem.readDirectory(source))
		{
			var srcPath:String = Path.join([source, entry]);
			var dstPath:String = Path.join([target, entry]);
			if (FileSystem.isDirectory(srcPath))
				copyModFolderRecursive(srcPath, dstPath);
			else
			{
				var parentDir:String = Path.directory(dstPath);
				if (parentDir != null && parentDir.length > 0 && !FileSystem.exists(parentDir))
					FileSystem.createDirectory(parentDir);
				File.copy(srcPath, dstPath);
			}
		}
	}

	function importDroppedModFolder(path:String):Void
	{
		if (path == null || path.length < 1 || !FileSystem.exists(path) || !FileSystem.isDirectory(path))
			return;

		var folderName:String = Path.withoutDirectory(path);
		if (folderName == null || folderName.length < 1)
			return;

		copyModFolderRecursive(path, Paths.mods(folderName));
		reloadModsFromFreeplay();
	}

	function onDropFile(path:String):Void
	{
		if (player != null && player.playingMusic)
			return;
		importDroppedModFolder(path);
	}
	#end

	override function destroy():Void
	{
		#if (MODS_ALLOWED && sys && !mobile)
		if (FlxG.stage != null && FlxG.stage.window != null)
			FlxG.stage.window.onDropFile.remove(onDropFile);
		#end

		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		if (!stopMusicPlay && (FlxG.sound.music == null || !FlxG.sound.music.playing))
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}
}

class SongMetadataPsych
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var lastDifficulty:String = null;

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if (this.folder == null)
			this.folder = '';
	}
}

