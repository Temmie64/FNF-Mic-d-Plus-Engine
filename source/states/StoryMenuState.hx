package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import flixel.group.FlxGroup;
import flixel.graphics.FlxGraphic;
import flixel.addons.display.FlxBackdrop;
import flixel.tweens.FlxEase;
import flixel.util.FlxGradient;
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
	var weekCharacterThing:MenuCharacter;
	var selectable:Bool = false;

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
		DiscordClient.changePresence(Language.getPhrase('states.story_menu.presence', 'In the Menus'), null);
		#end

		final accept:String = (controls.mobileC) ? "A" : "ACCEPT";
		final reject:String = (controls.mobileC) ? "B" : "BACK";

		if (WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(backend.ScriptableState.tryCreate('ErrorState',
				new states.ErrorState(Language.getPhrase('states.story_menu.errors.no_weeks',
					'NO WEEKS ADDED FOR STORY MODE\n\nPress {1} to go to the Week Editor Menu.\nPress {2} to return to Main Menu.', [accept, reject]),
					function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
					function() MusicBeatState.switchState(backend.ScriptableState.tryCreate('MainMenuState', new states.MainMenuState())))));
			return;
		}

		if (curWeek >= WeekData.weeksList.length)
			curWeek = 0;

		scoreText = new FlxText(safeX(10), 10, 0,
			Language.getPhrase('states.story_menu.score', Language.getPhrase('week_score', 'WEEK SCORE: {1}'), [lerpScore]), 36);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32);
		scoreText.alignment = CENTER;
		scoreText.setBorderStyle(OUTLINE, 0xFF000000, 5, 1);
		scoreText.screenCenter(X);
		scoreText.x = safeX((safeWidth() - scoreText.width) / 2);

		txtWeekTitle = new FlxText(0, scoreText.y + scoreText.height + 5, 0, "", 32);
		txtWeekTitle.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		txtWeekTitle.alignment = CENTER;
		txtWeekTitle.screenCenter(X);
		txtWeekTitle.x = safeX((safeWidth() - txtWeekTitle.width) / 2);
		txtWeekTitle.alpha = 0;

		var ui_tex = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		bgSprite = new FlxSprite(0, 56);

		grpWeekText = new FlxTypedGroup<MenuItem>();
		add(grpWeekText);

		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();

		grpLocks = new FlxTypedGroup<FlxSprite>();
		add(grpLocks);

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
				weekThing.color = 0xFF6A0999;
				weekThing.antialiasing = ClientPrefs.data.antialiasing;
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
				new states.ErrorState(Language.getPhrase('states.story_menu.errors.no_visible_weeks',
					'NO VISIBLE WEEKS AVAILABLE FOR STORY MODE\n\nPress {1} to return to Main Menu.', [reject]), null,
					function() MusicBeatState.switchState(backend.ScriptableState.tryCreate('MainMenuState', new states.MainMenuState())))));
			return;
		}

		add(storyModeTop);
		add(storyModeBottom);

		WeekData.setDirectoryFromWeek(loadedWeeks[0]);
		var charArray:Array<String> = loadedWeeks[0].weekCharacters;
		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter(safeX((safeWidth() * 0.25) * (1 + char) - 150), charArray[char]);
			weekCharacterThing.y += 70;
			grpWeekCharacters.add(weekCharacterThing);
		}

		difficultySelectors = new FlxGroup();
		add(difficultySelectors);

		Difficulty.resetList();
		if (lastDifficultyName == '')
		{
			lastDifficultyName = Difficulty.getDefault();
		}
		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		sprDifficulty = new FlxSprite();
		sprDifficulty.antialiasing = ClientPrefs.data.antialiasing;
		difficultySelectors.add(sprDifficulty);

		add(grpWeekCharacters);

		var tracksSprite:FlxSprite = new FlxSprite(FlxG.width * 0.03, bgSprite.y + 400).loadGraphic(Paths.image('Menu_Tracks'));
		tracksSprite.antialiasing = ClientPrefs.data.antialiasing;
		tracksSprite.visible = false;
		add(tracksSprite);

		txtTracklist = new FlxText(safeX(safeWidth() * 0.05), tracksSprite.y + 100, 0, "INCLUDES FAMOUS\n TRACKS LIKE:\n\n", 32);
		txtTracklist.alignment = CENTER;
		txtTracklist.font = Paths.font("vcr.ttf");
		txtTracklist.setBorderStyle(OUTLINE, 0xFF000000, 5, 1);
		txtTracklist.color = 0xFFe55777;

		add(txtTracklist);
		add(scoreText);
		add(txtWeekTitle);

		changeWeek();
		changeDifficulty();

		addTouchPad('LEFT_FULL', 'A_B_X_Y');

		super.create();

		FlxTween.tween(storyModeBackground, {alpha: 1}, 0.8, {ease: FlxEase.quartInOut});
		FlxTween.tween(storyModeTop, {y: 0}, 0.8, {ease: FlxEase.quartInOut});
		FlxTween.tween(storyModeBottom, {y: FlxG.height - storyModeBottom.height}, 0.8, {ease: FlxEase.quartInOut});
		FlxG.camera.zoom = 0.6;
		FlxG.camera.alpha = 0;
		FlxTween.tween(FlxG.camera, {zoom: 1, alpha: 1}, 0.7, {ease: FlxEase.quartInOut});

		scoreText.alpha = 0;
		txtTracklist.y = FlxG.height + storyModeBottom.height + 60;
		FlxTween.tween(scoreText, {alpha: 1}, 0.8, {ease: FlxEase.quartInOut});
		FlxTween.tween(txtTracklist, {y: 320}, 0.8, {ease: FlxEase.quartInOut});
		FlxTween.tween(txtWeekTitle, {alpha: 0.7}, 0.8, {ease: FlxEase.quartInOut});

		new FlxTimer().start(0.7, function(tmr:FlxTimer)
		{
			selectable = true;
		});
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
		checker.x += 0.12 * elapsed * 60;
		checker.y += 0.34 * elapsed * 60;

		if (WeekData.weeksList.length < 1)
		{
			if (controls.BACK || (touchPad != null && touchPad.buttonB.justPressed) && !movedBack && !selectedWeek)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				movedBack = true;
				MusicBeatState.switchState(backend.ScriptableState.tryCreate('MainMenuState', new MainMenuState()));
			}
			return;
		}
		// scoreText.setFormat(Paths.font("vcr.ttf"), 32);
		if (intendedScore != lerpScore)
		{
			lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 30)));
			if (Math.abs(intendedScore - lerpScore) < 10)
				lerpScore = intendedScore;

			scoreText.text = Language.getPhrase('states.story_menu.score', Language.getPhrase('week_score', 'WEEK SCORE: {1}'), [lerpScore]);
		}

		// FlxG.watch.addQuick('font', scoreText.font);

		if (!movedBack && !selectedWeek && selectable)
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
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
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
			else if (controls.ACCEPT || (touchPad != null && touchPad.buttonA.justPressed))
				selectWeek();
		}

		if ((controls.BACK || (touchPad != null && touchPad.buttonB.justPressed)) && !movedBack && !selectedWeek && selectable)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			movedBack = true;
			MusicBeatState.switchState(backend.ScriptableState.tryCreate('PlaySelectionState', new PlaySelectionState()));
			FlxTween.tween(FlxG.camera, {zoom: 0.6, alpha: -0.6}, 0.8, {ease: FlxEase.quartInOut});
			FlxTween.tween(storyModeBackground, {alpha: 0}, 0.8, {ease: FlxEase.quartInOut});
			FlxTween.tween(checker, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
			FlxTween.tween(gradientBar, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
			FlxTween.tween(storyModeTop, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
			FlxTween.tween(storyModeBottom, {alpha: 0}, 0.3, {ease: FlxEase.quartInOut});
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
			{
				lock.y = weekItem.y;
				lock.visible = lock.y > FlxG.height / 2;
			}
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

				Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffic, PlayState.storyPlaylist[0].toLowerCase());
				PlayState.campaignScore = 0;
				PlayState.campaignMisses = 0;
				// Resetear estadísticas de la semana
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
			new FlxTimer().start(1, function(tmr:FlxTimer)
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

		var diff:String = Difficulty.getString(curDifficulty, false);
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

	var lerpScore:Int = 49324858;
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

		bgSprite.visible = true;
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
		weekCharacterThing.changeCharacter(weekArray[0]);
		weekCharacterThing.scale.set(0.8, 0.8);
		weekCharacterThing.updateHitbox();
		weekCharacterThing.x = 1240 - weekCharacterThing.width;
		weekCharacterThing.y = 300;

		switch (weekCharacterThing.character)
		{
			case 'parents-christmas':
				weekCharacterThing.x = safeX(safeWidth() - weekCharacterThing.width / 2);
			case 'senpai':
				weekCharacterThing.x = safeX(safeWidth() - weekCharacterThing.width / 1.5);
		}

		var stringThing:Array<String> = [];
		{
			for (i in 0...leWeek.songs.length)
			{
				stringThing.push(leWeek.songs[i][0]);
			}
		}

		txtTracklist.text = 'INCLUDES FAMOUS\n TRACKS LIKE:\n\n';
		for (i in 0...stringThing.length)
		{
			txtTracklist.text += stringThing[i] + '\n';
		}

		txtTracklist.text = txtTracklist.text.toUpperCase();

		txtTracklist.screenCenter(X);
		txtTracklist.x -= FlxG.width * 0.35;

		#if !switch
		intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
		#end
	}
}
