package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import flixel.group.FlxGroup;
import flixel.graphics.FlxGraphic;
import flixel.addons.display.FlxBackdrop;
import flixel.util.FlxGradient;
import flixel.tweens.FlxEase;
import objects.MenuItem;
import objects.MenuCharacter;
import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;
import backend.StageData;
#if mobile
import mobile.backend.MobileScaleMode;
#end

class StoryMenuState extends MusicBeatState
{
	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>();

	public var scoreText:FlxText;

	public static var lastDifficultyName:String = '';

	public var curDifficulty:Int = 1;

	public var txtWeekTitle:FlxText;
	public var bgSprite:FlxSprite;

	public static var curWeek:Int = 0;

	public var txtTracklist:FlxText;

	public var grpWeekText:FlxTypedGroup<MenuItem>;
	public var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;

	public var grpLocks:FlxTypedGroup<FlxSprite>;

	public var difficultySelectors:FlxGroup;
	public var sprDifficulty:FlxSprite;
	public var checker:FlxBackdrop;
	public var storyModeBackground:FlxSprite;
	public var storyModeBottom:FlxSprite;
	public var storyModeTop:FlxSprite;
	public var gradientBar:FlxSprite;

	public var loadedWeeks:Array<WeekData> = [];

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

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		persistentUpdate = persistentDraw = true;
		PlayState.isStoryMode = true;
		WeekData.reloadWeekFiles(true);

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
			MusicBeatState.switchState(backend.ScriptableState.tryCreate('ErrorState',
				new states.ErrorState("NO WEEKS ADDED FOR STORY MODE\n\nPress " + accept + " to go to the Week Editor Menu.\nPress " + reject
					+ " to return to Main Menu.",
					function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
					function() MusicBeatState.switchState(backend.ScriptableState.tryCreate('MainMenuState', new states.MainMenuState())))));
			return;
		}

		if (curWeek >= WeekData.weeksList.length)
			curWeek = 0;

		scoreText = new FlxText(0, 10, 0, Language.getPhrase('week_score', 'WEEK SCORE: {1}', [lerpScore]), 36);
		scoreText.setBorderStyle(OUTLINE, 0xFF000000, 5, 1);
		scoreText.alignment = CENTER;
		scoreText.setFormat(Paths.font("vcr.ttf"), 32);
		scoreText.screenCenter(X);
		scoreText.x = safeX((safeWidth() - scoreText.width) / 2);

		storyModeTop = new FlxSprite().loadGraphic(Paths.image('MicUp/Week_Top'));
		storyModeBottom = new FlxSprite().loadGraphic(Paths.image('MicUp/Week_Bottom'));
		gradientBar = FlxGradient.createGradientFlxSprite(Math.round(FlxG.width), 512, [0x00FF0000, 0x55F8FFAB, 0xAAFFDEF2], 1, 90, true);
		checker = new FlxBackdrop(Paths.image('MicUp/Week_Checker'), flixel.util.FlxAxes.XY, 0.2, 0.2);
		storyModeBackground = new FlxSprite(-89).loadGraphic(Paths.image('MicUp/wBG_Main'));
		storyModeBackground.scrollFactor.set(0, 0);
		storyModeBackground.setGraphicSize(Std.int(storyModeBackground.width * 1.1));
		storyModeBackground.updateHitbox();
		storyModeBackground.screenCenter();
		storyModeBackground.antialiasing = ClientPrefs.data.antialiasing;
		storyModeBackground.alpha = 0;
		add(storyModeBackground);

		gradientBar.y = FlxG.height - gradientBar.height;
		gradientBar.scrollFactor.set(0, 0);
		add(gradientBar);
		add(checker);
		checker.scrollFactor.set(0, 0.07);

		txtWeekTitle = new FlxText(0, scoreText.y + scoreText.height + 5, 0, "", 32);
		txtWeekTitle.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		txtWeekTitle.screenCenter(X);
		txtWeekTitle.alpha = 0.7;

		var ui_tex = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		bgSprite = new FlxSprite(0, 56);

		grpWeekText = new FlxTypedGroup<MenuItem>();

		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();

		grpLocks = new FlxTypedGroup<FlxSprite>();

		var num:Int = 0;
		var itemTargetY:Float = 0;
		for (i in 0...WeekData.weeksList.length)
		{
			var weekFile:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			if (weekFile == null)
				continue;
			var isLocked:Bool = weekIsLocked(WeekData.weeksList[i]);
			if (!isLocked || !weekFile.hiddenUntilUnlocked)
			{
				loadedWeeks.push(weekFile);
				WeekData.setDirectoryFromWeek(weekFile);
				var weekThing:MenuItem = new MenuItem(0, bgSprite.y + 396, WeekData.weeksList[i]);
				weekThing.y += ((weekThing.height + 20) * num);
				weekThing.ID = num;
				weekThing.targetY = itemTargetY;
				itemTargetY += Math.max(weekThing.height, 110) + 10;
				grpWeekText.add(weekThing);

				weekThing.screenCenter(X);
				// weekThing.updateHitbox();

				// Needs an offset thingie
				if (isLocked)
				{
					var lock:FlxSprite = new FlxSprite(weekThing.width + 10 + weekThing.x);
					lock.antialiasing = ClientPrefs.data.antialiasing;
					lock.frames = ui_tex;
					lock.animation.addByPrefix('lock', 'lock');
					lock.animation.play('lock');
					lock.ID = weekThing.ID;
					grpLocks.add(lock);
				}
				num++;
			}
		}

		if (loadedWeeks.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(backend.ScriptableState.tryCreate('ErrorState',
				new states.ErrorState("NO VISIBLE WEEKS AVAILABLE FOR STORY MODE\n\nPress " + reject + " to return to Main Menu.", null,
					function() MusicBeatState.switchState(backend.ScriptableState.tryCreate('MainMenuState', new states.MainMenuState())))));
			return;
		}

		WeekData.setDirectoryFromWeek(loadedWeeks[0]);
		var charArray:Array<String> = loadedWeeks[0].weekCharacters;
		var weekCharacterThing:MenuCharacter = new MenuCharacter(safeX(safeWidth() * 0.25), charArray[1]);
		weekCharacterThing.y += 70;
		grpWeekCharacters.add(weekCharacterThing);

		storyModeTop.antialiasing = ClientPrefs.data.antialiasing;
		storyModeTop.scrollFactor.set(0, 0);
		storyModeTop.screenCenter();
		storyModeTop.y = -200;

		storyModeBottom.antialiasing = ClientPrefs.data.antialiasing;
		storyModeBottom.scrollFactor.set(0, 0);
		storyModeBottom.screenCenter();
		storyModeBottom.y = FlxG.height + storyModeBottom.height;

		difficultySelectors = new FlxGroup();

		Difficulty.resetList();
		if (lastDifficultyName == '')
		{
			lastDifficultyName = Difficulty.getDefault();
		}
		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		sprDifficulty = new FlxSprite();
		sprDifficulty.antialiasing = ClientPrefs.data.antialiasing;
		difficultySelectors.add(sprDifficulty);
		add(bgSprite);
		add(grpWeekText);
		add(grpLocks);
		add(grpWeekCharacters);
		add(storyModeTop);
		add(storyModeBottom);
		add(difficultySelectors);

		var tracksSprite:FlxSprite = new FlxSprite(safeX(safeWidth() * 0.03), bgSprite.y + 400).loadGraphic(Paths.image('Menu_Tracks'));
		tracksSprite.antialiasing = ClientPrefs.data.antialiasing;
		tracksSprite.visible = false;
		add(tracksSprite);

		txtTracklist = new FlxText(safeX(safeWidth() * 0.05), tracksSprite.y + 100, 0, "INCLUDES FAMOUS\n TRACKS LIKE:\n\n", 32);
		txtTracklist.alignment = CENTER;
		txtTracklist.font = Paths.font("vcr.ttf");
		txtTracklist.color = 0xFFe55777;
		txtTracklist.setBorderStyle(OUTLINE, 0xFF000000, 5, 1);
		add(txtTracklist);
		add(scoreText);
		add(txtWeekTitle);

		changeWeek();
		changeDifficulty();

		addTouchPad('LEFT_FULL', 'A_B_X_Y');

		super.create();

		FlxTween.tween(storyModeTop, {y: 0}, 0.8, {ease: FlxEase.quartInOut});
		FlxTween.tween(storyModeBottom, {y: FlxG.height - storyModeBottom.height}, 0.8, {ease: FlxEase.quartInOut});
		FlxTween.tween(storyModeBackground, {alpha: 1}, 0.8, {ease: FlxEase.quartInOut});
		FlxG.camera.zoom = 0.6;
		FlxG.camera.alpha = 0;
		FlxTween.tween(FlxG.camera, {zoom: 1, alpha: 1}, 0.7, {ease: FlxEase.quartInOut});
	}

	override function closeSubState()
	{
		persistentUpdate = true;
		changeWeek();
		super.closeSubState();
		removeTouchPad();
		addTouchPad('LEFT_FULL', 'A_B_X_Y');
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (WeekData.weeksList.length < 1)
		{
			if ((controls.BACK || (touchPad != null && touchPad.buttonB.justPressed)) && !movedBack && !selectedWeek)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				movedBack = true;
				MusicBeatState.switchState(backend.ScriptableState.tryCreate('MainMenuState', new MainMenuState()));
			}
			return;
		}
		if (intendedScore != lerpScore)
		{
			lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, FlxMath.bound(elapsed * 30, 0, 1)));
			if (Math.abs(intendedScore - lerpScore) < 10)
				lerpScore = intendedScore;

			scoreText.text = Language.getPhrase('week_score', 'WEEK SCORE: {1}', [lerpScore]);
			scoreText.x = safeX((safeWidth() - scoreText.width) / 2);
		}

		checker.x -= 0.45 / (ClientPrefs.data.framerate / 60);
		checker.y -= 0.16 / (ClientPrefs.data.framerate / 60);

		if (!movedBack && !selectedWeek)
		{
			var changeDiff = false;
			if (controls.UI_UP_P || (touchPad != null && touchPad.buttonUp.justPressed))
			{
				changeWeek(-1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeDiff = true;
			}

			if (controls.UI_DOWN_P || (touchPad != null && touchPad.buttonDown.justPressed))
			{
				changeWeek(1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeDiff = true;
			}

			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeWeek(-FlxG.mouse.wheel);
				changeDifficulty();
			}

			if (controls.UI_RIGHT_P || (touchPad != null && touchPad.buttonRight.justPressed))
				changeDifficulty(1);
			else if (controls.UI_LEFT_P || (touchPad != null && touchPad.buttonLeft.justPressed))
				changeDifficulty(-1);
			else if (changeDiff)
				changeDifficulty();

			if (FlxG.keys.justPressed.CONTROL || (touchPad != null && touchPad.buttonX.justPressed))
			{
				persistentUpdate = false;
				openSubState(backend.ScriptableSubstate.tryCreate('options.GameplayChangersSubstate', new GameplayChangersSubstate()));
				removeTouchPad();
			}
			else if (controls.RESET || (touchPad != null && touchPad.buttonY.justPressed))
			{
				persistentUpdate = false;
				openSubState(backend.ScriptableSubstate.tryCreate('ResetScoreSubState', new ResetScoreSubState('', curDifficulty, '', curWeek)));
				removeTouchPad();
			}
			else if (controls.ACCEPT || FlxG.mouse.justPressed || (touchPad != null && touchPad.buttonA.justPressed))
				selectWeek();
		}

		if ((controls.BACK || FlxG.mouse.justPressedRight || (touchPad != null && touchPad.buttonB.justPressed)) && !movedBack && !selectedWeek)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			movedBack = true;
			#if DISCORD_ALLOWED
			DiscordClient.changePresence("Going Back!", null);
			#end
			FlxTween.tween(FlxG.camera, {zoom: 0.6, alpha: -0.6}, 0.8, {ease: FlxEase.quartInOut});
			FlxTween.tween(storyModeBackground, {alpha: 0}, 0.8, {ease: FlxEase.quartInOut});
			FlxTween.tween(checker, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
			FlxTween.tween(gradientBar, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
			FlxTween.tween(storyModeTop, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
			FlxTween.tween(storyModeBottom, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
			MusicBeatState.switchState(backend.ScriptableState.tryCreate('PlaySelectionState', new PlaySelectionState()));

			/*new FlxTimer().start(0.8, function(tmr:FlxTimer)
			{
				MusicBeatState.switchState(backend.ScriptableState.tryCreate('PlaySelectionState', new PlaySelectionState()));
			});*/
		}

		var selectedItem:MenuItem = grpWeekText.members[curWeek];
		if (selectedItem == null)
			return;

		var offY:Float = selectedItem.targetY;
		for (num => item in grpWeekText.members)
		{
			if (item != null)
				item.y = FlxMath.lerp(item.targetY - offY + 480, item.y, Math.exp(-elapsed * 10.2));
		}

		for (num => lock in grpLocks.members)
		{
			if (lock == null || lock.ID < 0 || lock.ID >= grpWeekText.members.length)
				continue;

			var weekItem:MenuItem = grpWeekText.members[lock.ID];
			if (weekItem != null)
				lock.y = weekItem.y + weekItem.height / 2 - lock.height / 2;
		}
	}

	var movedBack:Bool = false;
	var selectedWeek:Bool = false;
	var stopspamming:Bool = false;

	function selectWeek()
	{
		if (!weekIsLocked(loadedWeeks[curWeek].fileName))
		{
			// We can't use Dynamic Array .copy() because that crashes HTML5, here's a workaround.
			var songArray:Array<String> = [];
			var leWeek:Array<Dynamic> = loadedWeeks[curWeek].songs;
			for (i in 0...leWeek.length)
			{
				songArray.push(leWeek[i][0]);
			}

			// Nevermind that's stupid lmao
			try
			{
				PlayState.storyPlaylist = songArray;
				PlayState.isStoryMode = true;
				selectedWeek = true;

				var diffic = Difficulty.getFilePath(curDifficulty);
				if (diffic == null)
					diffic = '';

				PlayState.storyDifficulty = curDifficulty;

				PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffic, PlayState.storyPlaylist[0].toLowerCase());
				PlayState.campaignScore = 0;
				PlayState.campaignMisses = 0;
				PlayState.campaignFlawlesss = 0;
				PlayState.campaignSicks = 0;
				PlayState.campaignGoods = 0;
				PlayState.campaignBads = 0;
				PlayState.campaignShits = 0;
				PlayState.campaignMaxCombo = 0;
				PlayState.campaignTotalNotes = 0;
				PlayState.campaignSongsPlayed = [];
				PlayState.campaignAccuracySum = 0;
				PlayState.campaignSongsCount = 0;

				FlxTween.tween(FlxG.camera, {zoom: 1.8, alpha: -0.6}, 1.8, {ease: FlxEase.quartOut});
				FlxTween.tween(storyModeBackground, {alpha: 0}, 0.6, {ease: FlxEase.quartInOut});
				FlxTween.tween(checker, {alpha: 0}, 0.6, {ease: FlxEase.quartInOut});
				FlxTween.tween(gradientBar, {alpha: 0}, 0.6, {ease: FlxEase.quartInOut});
				FlxTween.tween(storyModeTop, {alpha: 0}, 0.8, {ease: FlxEase.quartInOut});
				FlxTween.tween(storyModeBottom, {alpha: 0}, 0.8, {ease: FlxEase.quartInOut});
				FlxTween.tween(scoreText, {y: -50, alpha: 0}, 0.8, {ease: FlxEase.quartInOut});
				FlxTween.tween(txtWeekTitle, {y: -50, alpha: 0}, 0.8, {ease: FlxEase.quartInOut});
				FlxTween.tween(sprDifficulty, {y: -120, alpha: 0}, 0.8, {ease: FlxEase.quartInOut});
			}
			catch (e:Dynamic)
			{
				trace('ERROR! $e');
				return;
			}

			if (stopspamming == false)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));

				grpWeekText.members[curWeek].isFlashing = true;
				for (char in grpWeekCharacters.members)
				{
					if (char.character != '' && char.hasConfirmAnimation)
					{
						char.animation.play('confirm');
					}
				}
				stopspamming = true;
			}

			var directory = StageData.forceNextDirectory;
			LoadingState.loadNextDirectory();
			StageData.forceNextDirectory = directory;
			@:privateAccess
			if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
				Paths.freeGraphicsFromMemory();
			}
			LoadingState.prepareToSong();
			new FlxTimer().start(0.5, function(tmr:FlxTimer)
			{
				#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
				LoadingState.returnState = new StoryMenuState(); // Establecer estado de retorno
				LoadingState.loadAndSwitchState(new PlayState(), true);
				FreeplayState.destroyFreeplayVocals();
			}); #if (MODS_ALLOWED && DISCORD_ALLOWED) DiscordClient.loadModRPC(); #end
		}
		else
			FlxG.sound.play(Paths.sound('cancelMenu'));
	}

	function changeDifficulty(change:Int = 0):Void
	{
		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = Difficulty.list.length - 1;
		if (curDifficulty >= Difficulty.list.length)
			curDifficulty = 0;

		WeekData.setDirectoryFromWeek(loadedWeeks[curWeek]);

		var diff:String = Difficulty.getString(curDifficulty);
		var newImage:FlxGraphic = Paths.image('menudifficulties/' + Paths.formatToSongPath(diff));
		// trace(Mods.currentModDirectory + ', menudifficulties/' + Paths.formatToSongPath(diff));

		if (sprDifficulty.graphic != newImage)
		{
			sprDifficulty.loadGraphic(newImage);
			sprDifficulty.x = safeX((safeWidth() - sprDifficulty.width) / 2);
			sprDifficulty.y = txtWeekTitle.y + 5;
			sprDifficulty.alpha = 0;
			FlxTween.cancelTweensOf(sprDifficulty);
			FlxTween.tween(sprDifficulty, {y: txtWeekTitle.y + 62, alpha: 1}, 0.07);
		}
		lastDifficultyName = diff;

		#if !switch
		intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
		#end
	}

	var lerpScore:Int = 0;
	var intendedScore:Int = 0;

	function changeWeek(change:Int = 0):Void
	{
		curWeek += change;

		if (curWeek >= loadedWeeks.length)
			curWeek = 0;
		if (curWeek < 0)
			curWeek = loadedWeeks.length - 1;

		var leWeek:WeekData = loadedWeeks[curWeek];
		WeekData.setDirectoryFromWeek(leWeek);

		var leName:String = Language.getPhrase('storyname_${leWeek.fileName}', leWeek.storyName);
		txtWeekTitle.text = leName.toUpperCase();
		txtWeekTitle.x = safeX((safeWidth() - txtWeekTitle.width) / 2);

		var unlocked:Bool = !weekIsLocked(leWeek.fileName);
		for (num => item in grpWeekText.members)
		{
			item.alpha = 0.6;
			if (num - curWeek == 0 && unlocked)
				item.alpha = 1;
		}
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Deciding to play week " + curWeek + "!", null);
		#end

		bgSprite.visible = false;
		{
			var assetName:String = leWeek.weekBackground;
			if (assetName == null || assetName.length < 1)
			{
				bgSprite.visible = false;
			}
			else
			{
				bgSprite.loadGraphic(Paths.image('menubackgrounds/menu_' + assetName));
				bgSprite.color = FlxColor.WHITE;
			}
		}
		var storyWeekIndex:Int = WeekData.getWeekIndex(leWeek.fileName);
		PlayState.storyWeek = storyWeekIndex >= 0 ? storyWeekIndex : curWeek;

		Difficulty.loadFromWeek();
		difficultySelectors.visible = unlocked;

		if (Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		var newPos:Int = Difficulty.list.indexOf(lastDifficultyName);
		// trace('Pos of ' + lastDifficultyName + ' is ' + newPos);
		if (newPos > -1)
		{
			curDifficulty = newPos;
		}
		updateText();
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		if (leWeek == null)
			return true;
		return (!leWeek.startUnlocked
			&& leWeek.weekBefore.length > 0
			&& (!weekCompleted.exists(leWeek.weekBefore) || !weekCompleted.get(leWeek.weekBefore)));
	}

	function updateText()
	{
		var leWeek:WeekData = loadedWeeks[curWeek];
		grpWeekCharacters.visible = true;

		var weekArray:Array<String> = loadedWeeks[curWeek].weekCharacters;
		{
			for (i in 0...grpWeekCharacters.length)
			{
				grpWeekCharacters.members[i].changeCharacter(weekArray[1]);
			}
		}

		var stringThing:Array<String> = [];
		{
			for (i in 0...leWeek.songs.length)
			{
				stringThing.push(leWeek.songs[i][0]);
			}
		}

		txtTracklist.text = '';
		for (i in 0...stringThing.length)
		{
			txtTracklist.text += stringThing[i] + '\n';
		}

		txtTracklist.text = txtTracklist.text.toUpperCase();

		txtTracklist.x = safeX((safeWidth() - txtTracklist.width) / 2 - safeWidth() * 0.35);

		#if !switch
		intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
		#end
	}
}
