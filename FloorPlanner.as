package 
{
	import com.adobe.images.JPGEncoder;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.FocusEvent;
	import flash.filters.DropShadowFilter;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.geom.Vector3D;
	import flash.net.FileReference;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.utils.ByteArray;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	import flash.utils.getTimer;
	import flash.external.ExternalInterface;
	
	[SWF(width = "1024", height = "768", backgroundColor = "#FFFFFF", frameRate = "30")];
	
	/**
	 * ...
	 * 
	 * @author mj
	 */
	public class FloorPlanner extends Sprite 
	{
		public static var apiUrl:String = "http://ruanzhuangyun.cn/";// "http://symspace.e360.cn/";
		public static var userId:String = null;
		public static var userToken:String = null;
		
		public static var Copy:XML = null;				// copy of all languages
		public static var Lang:XML = null;				// copy of current language
	
		private var mouseDownPt:Vector3D = null;		// point of last mouseDown
		private var mouseUpPt:Vector3D= null;			// point of last mouseUp
		private var grid:WireGrid = null;				
		private var floorPlan:FloorPlan = null;			
		
		private var undoStk:Vector.<String> = null;		// stack of JSON states
		private var redoStk:Vector.<String> = null;		// stack of JSON states
		
		private var topBar:Sprite = null;
		private var menu:Sprite = null;
		private var scaleSlider:Sprite = null;
		
		private var stepFn:Function = null;				// to exec every frame
		private var mouseDownFn:Function = null;		// to exec
		private var mouseUpFn:Function = null;			// to exec
		
		// ----- seems class names need to be mentioned once to be added in the compile
		private static const Assets:Array = [DoorDoubleSliding, DoorDoubleSwinging, DoorSingleSliding, DoorSingleSwinging,WindowDouble,WindowSingle,WindowTriple,
		DoorDoubleSlidingSV, DoorDoubleSwingingSV, DoorSingleSlidingSV, DoorSingleSwingingSV,WindowDoubleSV,WindowSingleSV,WindowTripleSV,
		Floor1, Floor2, Floor3, Floor4, Floor5, Floor6, Floor7, Floor8, Floor9, Floor10, Floor11, Floor12, Floor13,
		MenuIcoDrawDoor, MenuIcoDrawWall, MenuIcoDrawLine, MenuIcoFile, MenuIcoFurniture, MenuIcoNew, MenuIcoRedo, MenuIcoSave, MenuIcoText, MenuIcoUndo,
		ArmChair, BathTub, BathTubL, BathTubRound, BedDouble, BedSingle, Cabinet, Chair, Oven, Piano, RoundSofa, Rug, Shelfs, ShoeCabinet, SinkKitchen, SinkRound,
		Sofa2,Sofa3,Sofa4,TableL,TableOctagon,TableRect,TableRound,TableSquare,Toilet,ToiletSquat,TVFlat,Stove];
		
		
		//=============================================================================================
		//
		//=============================================================================================
		public function FloorPlanner():void 
		{
			var ppp:Sprite = this;
			function processXML(ev:Event):void
			{
				Copy = new XML(ev.target.data);
				Lang = Copy.CN[0];
				if (stage) init();
				else ppp.addEventListener(Event.ADDED_TO_STAGE, init);
			}
		
			var ldr:URLLoader = new URLLoader();
			ldr.load(new URLRequest("copy.xml"));
			ldr.addEventListener(Event.COMPLETE, processXML);
			
			if (root.loaderInfo.parameters.httpURL!=null) apiUrl = root.loaderInfo.parameters.httpURL+"";	
			if (root.loaderInfo.parameters.token!=null) userToken = root.loaderInfo.parameters.token+"";
			
			try {
				apiUrl = ExternalInterface.call("window.location.hostname.toString");
			} catch (e:Error) {trace("ExternalInterface call error : "+ e);}
		}//
		
		//=============================================================================
		// gets the userId and userToken
		//=============================================================================
		private function createLoginPage(callBack:Function=null):Sprite
		{
			var s:Sprite = new Sprite();
			s.graphics.beginFill(0x000000,0.8);
			s.graphics.drawRect(0,0,stage.stageWidth,stage.stageHeight);
			s.graphics.endFill();
			var login:MovieClip = new PopLogin();
			login.x = (stage.stageWidth-login.width)/2;
			login.y = (stage.stageHeight-login.height)/2;
			s.addChild(login);
			
			var tff:TextFormat = login.usernameTf.defaultTextFormat;
			tff.color = 0x999999;
			login.usernameTf.setTextFormat(tff);
			login.passwordTf.setTextFormat(tff);
			login.usernameTf.type = "input";
			login.passwordTf.type = "input";
			
			function enterFrameHandler(ev:Event):void
			{
				if (s.stage==null) 
				{
					s.removeEventListener(Event.ENTER_FRAME,enterFrameHandler);
					return;
				}
				if (s.width!=stage.stageWidth || s.height!=stage.stageHeight)
				{
					s.graphics.clear();
					s.graphics.beginFill(0x000000,0.8);
					s.graphics.drawRect(0,0,stage.stageWidth,stage.stageHeight);
					s.graphics.endFill();
				}
				login.x = (stage.stageWidth-login.width)/2;
				login.y = (stage.stageHeight-login.height)/2;
			}//endfunction
			s.addEventListener(Event.ENTER_FRAME,enterFrameHandler);
			
			function keyHandler(event:KeyboardEvent):void
			{
				// if the key is ENTER
				if(event.charCode == 13)
				{
					if (login.usernameTf.text!="" && login.passwordTf.text!="")
					{
						var rootUrl:String = apiUrl;
						try {
							rootUrl = ExternalInterface.call("window.location.hostname.toString");
						} catch (e:Error) {trace("ExternalInterface call error : "+ e);}
						var ldr:URLLoader = new URLLoader();
						var req:URLRequest = new URLRequest(rootUrl+"?n=api&a=login&c=user");
						req.method = "post";  
						var vars : URLVariables = new URLVariables(); 
						vars.n = "api";
						vars.a = "login";
						vars.c = "user"
						vars.username = login.usernameTf.text;  
						vars.password = login.passwordTf.text;  
						req.data = vars;
						ldr.load(req);
						ldr.addEventListener(Event.COMPLETE, onComplete);  
						function onComplete(e : Event):void
						{  
							trace("login return="+ldr.data);
							var o:Object = JSON.parse(ldr.data);
							login.textTf.text = o.meta.message; 
							if (o.meta.code==200)
							{
								userId = o.data.userid;
								userToken = o.data.utoken;
								if (callBack!=null) callBack();
							}
						}
					}
				}
			}//endfunction
			
			function focusHandler(ev:Event):void
			{
				(TextField)(ev.target).text = "";
			}
			login.usernameTf.addEventListener(FocusEvent.FOCUS_IN,focusHandler);
			login.passwordTf.addEventListener(FocusEvent.FOCUS_IN,focusHandler);
			login.usernameTf.addEventListener(KeyboardEvent.KEY_DOWN,keyHandler);
			login.passwordTf.addEventListener(KeyboardEvent.KEY_DOWN,keyHandler);
			
			return s;
		}//endfunction
		
		//=============================================================================================
		// takes a 2D snapshot of current floorplan
		//=============================================================================================
		public function saveToJpg():void
		{
			var bnds:Rectangle = floorPlan.overlay.getBounds(floorPlan.overlay);
			var bmd:BitmapData = new BitmapData(bnds.width+60,bnds.height+60,false,0x00000000);
			var mat:Matrix = new Matrix(1,0,0,1,-bnds.left+30,-bnds.top+30);
			bmd.draw(grid,mat);
			bmd.draw(floorPlan.overlay,mat);
			
			var jpgEnc:JPGEncoder = new JPGEncoder(80);
			var ba:ByteArray = jpgEnc.encode(bmd);
			
			var fr:FileReference=new FileReference();
			fr.save(ba, "floorPlan.jpg"); 	
		}//endfunction
		
		//=============================================================================================
		// Entry point
		//=============================================================================================
		private function init(e:Event=null):void
		{
			stage.scaleMode = "noScale";
			stage.align = "topLeft";
			removeEventListener(Event.ADDED_TO_STAGE, init);
			
			mouseDownPt = new Vector3D();
			mouseUpPt = new Vector3D();
			
			var sw:int = stage.stageWidth;
			var sh:int = stage.stageHeight;
			
			undoStk = new Vector.<String>();
			redoStk = new Vector.<String>();
			
			// ----- add grid background --------------------------------------
			grid = new WireGrid();
			grid.x = sw/2;
			grid.y = sh/2;
			grid.update();
			addChild(grid);
			
			// ----- floorplan drawing sprite ---------------------------------
			floorPlan = new FloorPlan();
			grid.addChild(floorPlan.overlay);
			
			// ----- create top bar -------------------------------------------
			topBar = new TopBarMenu(Lang.TopBar.btn,function (i:int):void 
			{
				//prn("TopBarMenu "+i);
				if (i==0)		// file 
				{
					showSaveLoadMenu();
				}
				else if (i==1)	// furniture
				{
					showFurnitureMenu();
					modeDefault();
				}
				else if (i==2)	// doors
				{
					showDoorsMenu();
					modeDefault();
				}
				else if (i==3)	// walls
				{
					modeAddWalls();
				}
				else if (i==4)	// lines
				{
					modeAddLines();
				}
				else if (i==5)	// text
				{
					var csr:Sprite = new Sprite();
					csr.graphics.lineStyle(0);
					csr.graphics.beginFill(0xFFFFFF,1);
					csr.graphics.drawCircle(0,0,5);
					csr.graphics.endFill();
					var ico:Sprite = new MenuIcoText();
					ico.x = 10;
					ico.y = 10;
					csr.addChild(ico);
					csr.x = floorPlan.overlay.mouseX;
					csr.y = floorPlan.overlay.mouseY;
					floorPlan.overlay.addChild(csr);
					csr.startDrag(true);
					function setLab(ev:Event):void
					{
						csr.stopDrag();
						floorPlan.overlay.removeChild(csr);
						floorPlan.createLabel(csr.x,csr.y);
					}
					csr.addEventListener(MouseEvent.MOUSE_UP,setLab);
				}
				else if (i==6)	// save o image
				{
					prn(floorPlan.exportData());
					saveToJpg();
				}
				else if (i==7)	// undo
				{
					if (undoStk.length>0)
					{
						redoStk.push(floorPlan.exportData());
						//prn("undo:" +undoStk[undoStk.length-1]);
						floorPlan.importData(undoStk.pop());
					}
				}
				else if (i==8)	// redo
				{
					if (redoStk.length>0)
					{
						undoStk.push(floorPlan.exportData());
						//prn("undo:" +redoStk[redoStk.length-1]);
						floorPlan.importData(redoStk.pop());
					}
				}
			});
			addChild(topBar);
			
			// ----- zoom slider
			scaleSlider = createVSlider(["0.5x","1x","2x"],function(f:Number):void {grid.zoom(0.5*(1-f)+2*f);});
			scaleSlider.x = stage.stageWidth/20;
			scaleSlider.y = stage.stageHeight/20 + topBar.height;
			addChild(scaleSlider);
			
			// ----- add controls
			stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
			stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
			
			function initInterractions():void
			{
				// ----- enter default editing mode
				showFurnitureMenu();
				modeDefault();
				
				// ----- create default room walls
				createDefaRoom();
			}//endfunction
			
			if (userToken==null)
			{
				//defaLogin(initInterractions);
				
				// ----- force user to login ----------------------------
				var loginPage:Sprite = createLoginPage(function():void 
				{
					if (loginPage.parent != null) loginPage.parent.removeChild(loginPage); 
					initInterractions();
				});
				addChild(loginPage);
			}
			else initInterractions();
		}//endfunction
		
		//=============================================================================================
		// default login wih shaoyiting 
		//=============================================================================================
		private function  defaLogin(callBack:Function):void
		{
			var ldr:URLLoader = new URLLoader();
			var req:URLRequest = new URLRequest(apiUrl+"?n=api&a=login&c=user");
			req.method = URLRequestMethod.POST;
			var vars : URLVariables = new URLVariables(); 
			vars.n = "api";
			vars.a = "login";
			vars.c = "user";
			vars.username = "shaoyiting";
			vars.password = "shaoyiting";  
			req.data = vars;
			ldr.load(req);
			ldr.addEventListener(Event.COMPLETE, onComplete);  
			function onComplete(e : Event):void
			{  
				trace("login return="+ldr.data);
				var o:Object = JSON.parse(ldr.data);
				if (o.meta.code==200)
				{
					userId = o.data.userid;
					userToken = o.data.utoken;
					trace("userId="+userId+"  userToken="+userToken);
					if (callBack!=null) callBack();
				}
			}
		}
		
		//=============================================================================================
		// default room to look at just so it wouldnt be too boring 
		//=============================================================================================
		private function createDefaRoom():void
		{
			floorPlan.importData('{"Joints":[{"y":-395,"x":-250},{"y":-396,"x":249},{"y":180,"x":250},{"y":180,"x":150},{"y":230,"x":50},{"y":230,"x":-50},{"y":180,"x":-150},{"y":180,"x":-250},{"y":-517,"x":543},{"y":89,"x":543},{"y":89,"x":249},{"y":-192,"x":249},{"y":-192,"x":249},{"y":-193,"x":543},{"y":-192,"x":249},{"y":-343,"x":-250},{"y":-343,"x":-524},{"y":-269,"x":-627},{"y":-113,"x":-627},{"y":-27,"x":-527},{"y":-27,"x":-406},{"y":141,"x":-406},{"y":141,"x":-250},{"y":-517,"x":249},{"y":-378,"x":543},{"y":-378,"x":701},{"y":-97,"x":701},{"y":-97,"x":543},{"y":89,"x":543},{"y":-97,"x":701},{"y":-396,"x":-138.00000000000003},{"y":-707,"x":-138},{"y":-707,"x":-524},{"y":-343,"x":-524},{"y":-707,"x":-524}],"Furniture":[{"x":485,"scX":1.2509692700746744,"color":0,"scY":1.2464523664404727,"cls":"Toilet","y":-86,"rot":89.70202789452766},{"x":451,"scX":1,"color":0,"scY":1,"cls":"SinkRound","y":-163,"rot":0},{"x":442,"scX":1,"color":0,"scY":1,"cls":"BathTub","y":37,"rot":90.4262926392602},{"x":-217,"scX":1,"color":0,"scY":1,"cls":"TVFlat","y":71,"rot":-90.27906677101664},{"x":-164,"scX":1,"color":0,"scY":1,"cls":"TableSquare","y":-117,"rot":0},{"x":206,"scX":1,"color":0,"scY":1,"cls":"Sofa4","y":48,"rot":-89.94349530479464},{"x":-473,"scX":0.6984775322209045,"color":0,"scY":0.6855680212976787,"cls":"Piano","y":-187,"rot":-118.87361735156438},{"x":457,"scX":1,"color":0,"scY":1,"cls":"BedDouble","y":-410,"rot":-0.14365196037870476},{"x":634,"scX":1,"color":0,"scY":1,"cls":"TableL","y":-311,"rot":-179.86341913948408},{"x":54,"scX":1,"color":0,"scY":1,"cls":"TableOctagon","y":-204,"rot":0},{"x":-361,"scX":1,"color":0,"scY":1,"cls":"ArmChair","y":-285,"rot":0},{"x":-191,"scX":1,"color":0,"scY":1,"cls":"SinkKitchen","y":-462,"rot":90.04634954861659},{"x":-200,"scX":1,"color":0,"scY":1,"cls":"Stove","y":-645,"rot":89.86412658886046},{"x":-449,"scX":1,"color":0,"scY":1,"cls":"TableRect","y":-592,"rot":89.96651083627482}],"Labels":[],"Walls":[{"j2":3,"Doors":[],"j1":2,"w":20},{"j2":4,"Doors":[{"dir":0.617154761789942,"pivot":0.22742261910502903,"cls":"WindowSingle","side":"WindowSingleSV"}],"j1":3,"w":10},{"j2":5,"Doors":[{"dir":0.69,"pivot":0.16500000000000004,"cls":"WindowSingle","side":"WindowSingleSV"}],"j1":4,"w":10},{"j2":6,"Doors":[{"dir":0.617154761789942,"pivot":0.15142261910502908,"cls":"WindowSingle","side":"WindowSingleSV"}],"j1":5,"w":10},{"j2":7,"Doors":[],"j1":6,"w":20},{"j2":10,"Doors":[],"j1":2,"w":10},{"j2":10,"Doors":[],"j1":9,"w":10},{"j2":11,"Doors":[{"dir":0.541871921182266,"pivot":0.3645320197044335,"cls":"DoorSingleSwinging","side":"DoorSingleSwingingSV"}],"j1":1,"w":10},{"j2":11,"Doors":[{"dir":0.3914590747330961,"pivot":0.5444839857651245,"cls":"DoorSingleSwinging","side":"DoorSingleSwingingSV"}],"j1":10,"w":10},{"j2":11,"Doors":[],"j1":13,"w":10},{"j2":15,"Doors":[],"j1":0,"w":10},{"j2":17,"Doors":[{"dir":0.5440496786546839,"pivot":0.2247734199204044,"cls":"WindowSingle","side":"WindowSingleSV"}],"j1":16,"w":10},{"j2":18,"Doors":[{"dir":0.4423076923076923,"pivot":0.27884615384615385,"cls":"WindowSingle","side":"WindowSingleSV"}],"j1":17,"w":10},{"j2":19,"Doors":[{"dir":0.5231477854550612,"pivot":0.24911822040192444,"cls":"WindowSingle","side":"WindowSingleSV"}],"j1":18,"w":10},{"j2":20,"Doors":[{"dir":0.5702479338842975,"pivot":0.1859504132231405,"cls":"WindowSingle","side":"WindowSingleSV"}],"j1":19,"w":10},{"j2":21,"Doors":[],"j1":20,"w":10},{"j2":22,"Doors":[],"j1":7,"w":10},{"j2":22,"Doors":[{"dir":0.2272727272727273,"pivot":0.0578512396694215,"cls":"DoorSingleSwinging","side":"DoorSingleSwingingSV"}],"j1":15,"w":10},{"j2":22,"Doors":[{"dir":0.8269230769230769,"pivot":0.08012820512820518,"cls":"WindowDouble","side":"WindowDoubleSV"}],"j1":21,"w":10},{"j2":23,"Doors":[{"dir":0.4387755102040816,"pivot":0.5289115646258504,"cls":"WindowDouble","side":"WindowDoubleSV"}],"j1":8,"w":10},{"j2":23,"Doors":[],"j1":1,"w":10},{"j2":24,"Doors":[],"j1":8,"w":10},{"j2":25,"Doors":[],"j1":24,"w":10},{"j2":26,"Doors":[],"j1":25,"w":10},{"j2":27,"Doors":[],"j1":9,"w":10},{"j2":27,"Doors":[],"j1":13,"w":10},{"j2":27,"Doors":[],"j1":26,"w":10},{"j2":30,"Doors":[],"j1":0,"w":10},{"j2":30,"Doors":[],"j1":1,"w":10},{"j2":31,"Doors":[],"j1":30,"w":10},{"j2":32,"Doors":[{"dir":0.33419689119170987,"pivot":0.5582901554404145,"cls":"WindowDouble","side":"WindowDoubleSV"},{"dir":0.33419689119170987,"pivot":0.09974093264248704,"cls":"WindowDouble","side":"WindowDoubleSV"}],"j1":31,"w":10},{"j2":16,"Doors":[{"dir":0.7846715328467153,"pivot":0.0967153284671533,"cls":"DoorSingleSliding","side":"DoorSingleSlidingSV"}],"j1":15,"w":10},{"j2":16,"Doors":[{"dir":0.3543956043956044,"pivot":0.6112637362637362,"cls":"WindowDouble","side":"WindowDoubleSV"}],"j1":32,"w":10}]}');
			floorPlan.refresh();
		}//endfunction
		
		//=============================================================================================
		// default room to look at just so it wouldnt be too boring 
		//=============================================================================================
		private function createSquareRoom(w:int,h:int):void
		{
			floorPlan.importData('{"floorAreas":[{"flooring":1}],"Joints":[{"y":-'+h/2+',"x":-'+w/2+'},{"y":-'+h/2+',"x":'+w/2+'},{"y":'+h/2+',"x":'+w/2+'},{"y":'+h/2+',"x":-'+w/2+'}],"Walls":[{"w":10,"j1":0,"j2":1,"Doors":[]},{"w":10,"j1":1,"j2":2,"Doors":[]},{"w":10,"j1":2,"j2":3,"Doors":[]},{"w":10,"j1":3,"j2":0,"Doors":[]}],"Labels":[],"Furniture":[]}');
			floorPlan.refresh();
		}//endfunction
		
		//=============================================================================================
		// show save load selection
		//=============================================================================================
		private function showSaveLoadMenu():void
		{
			replaceMenu(new SaveLoadMenu(floorPlan,showBuildDfaultRoom));
		}//endfunction
		
		//=============================================================================================
		// show option to build a default room
		//=============================================================================================
		public function showBuildDfaultRoom():void
		{
			var w:int = 10; 
			var l:int = 5;
			var h:int = 2;
			replaceMenu(new DialogMenu("是否建标准房间",
										Vector.<String>([	"长度 =["+w+"]",
															"宽度 =["+l+"]",
															"高度 =["+h+"]",
														FloorPlanner.Lang.SaveLoad.Confirm.@txt,
														FloorPlanner.Lang.SaveLoad.Cancel.@txt]),
										Vector.<Function>([	function(val:String):void { w = parseFloat(val); if (isNaN(w) || w < 1) w = 1; },
															function(val:String):void { l = parseFloat(val); if (isNaN(l) || l < 1) l = 1; },					
															function(val:String):void { h = parseFloat(val); if (isNaN(h) || h < 1) h = 1; },
															function():void 
															{
																floorPlan.ceilingHeight = h*100;
																createSquareRoom(w * 100, l * 100);
																modeDefault();
															},
															modeDefault])));
		}
		
		//=============================================================================================
		// show available furniture selection from server
		//=============================================================================================
		private function showFurnitureMenu():void
		{
			replaceMenu(new ItemsMenu(function(prod:Object):void 
			{
				// ----- creates the Item and add to floorplan
				trace("SELECTED "+ Utils.prnObject(prod));
				var ico:Sprite = new Sprite();
				ico.addChild(new Bitmap(new BitmapData(100,100,true,0x66000000)));
				ico.getChildAt(0).x = -50;
				ico.getChildAt(0).y = -50;
				var itm:Item = new Item(ico);
				itm.id = prod.id;
				floorPlan.addItem(itm);
				
				// ----- loads the pic for the item
				var picUrl:String = prod.pic;
				if (prod.modelpics!=null && prod.modelpics.up!="false")	
					picUrl = prod.modelpics.up;
				picUrl = apiUrl+picUrl;
				if (picUrl.indexOf("http")==-1)	picUrl = "http://"+picUrl;
				Utils.loadAsset(picUrl,function(pic:DisplayObject):void 
				{
					trace(picUrl+"loaded, updating itm ico");
					var w:int = ico.width;
					var h:int = ico.height;
					while (ico.numChildren>0)	ico.removeChildAt(0);
					pic.x = -pic.width/2;
					pic.y = -pic.height/2;
					ico.addChild(pic);
					ico.width = w;
					ico.height = h;
				});
			},70,parseInt("01101111",2)));
		}//endfunction
		
		//=============================================================================================
		// show available furniture selection
		//=============================================================================================
		private function showFurnitureMenuO():void
		{
			replaceMenu(new AddFurnitureMenu(Lang.Items[0].item,function(idx:int):void
			{
				var IcoCls:Class = Class(getDefinitionByName(Lang.Items[0].item[idx].@cls));
				var ico:Sprite = new IcoCls();
				if (ico is MovieClip && (MovieClip)(ico).totalFrames>1)
				{
					var Icos:Vector.<Sprite> = new Vector.<Sprite>();
					var n:int = (MovieClip)(ico).totalFrames;
					for (var i:int=n-1; i>-1; i--)
					{
						ico = new IcoCls();
						(MovieClip)(ico).gotoAndStop(i+1);
						var sc:Number = Math.min(70/(ico.width),70/(ico.height))*0.8;
						var s:Sprite = new Sprite();
						ico.scaleX = ico.scaleY = sc;
						var b:Rectangle = ico.getBounds(ico);
						s.graphics.beginFill(0xFFFFFF,1);
						s.graphics.drawRoundRect(0,0,70,70,5);
						s.graphics.endFill();
						ico.x = (70-ico.width)/2-b.left*sc;
						ico.y = (70-ico.height)/2-b.top*sc;
						s.addChild(ico);
						Icos.unshift(s);
					}
					replaceMenu(new IconsMenu(Icos,Math.ceil(n/2),2,function (i:int):void 
					{
						ico.scaleX=ico.scaleY=1;
						(MovieClip)(ico).gotoAndStop(i+1);
						floorPlan.addFurniture(ico);
						showFurnitureMenu();
					}));
				}
				else
				{	
					floorPlan.addFurniture(ico);
				}
			}));
		}//endfunction
		
		//=============================================================================================
		// show available doors windows selection
		//=============================================================================================
		private function showDoorsMenu():void
		{
			replaceMenu(new AddFurnitureMenu(Lang.Ports[0].port,function(idx:int):void
			{
				var IcoCls:Class = Class(getDefinitionByName(Lang.Ports[0].port[idx].@cls));
				var SideIcoCls:Class = Class(getDefinitionByName(Lang.Ports[0].port[idx].@side));
				modeAddDoors(new IcoCls() as Sprite,new SideIcoCls() as Sprite);
			}));	
		}//endfunction
		
		//=============================================================================================
		// go into defacto edit mode
		//=============================================================================================
		private function modeDefault():void
		{
			prn("modeDefault");
			var px:int = 0;
			var py:int = topBar.height+5;
			
			function showFloorAreaProperties(area:FloorArea):void
			{
				replaceMenu(new DialogMenu(Lang.FloorProp.title.@txt+":"+int(area.area/100)/100+"m sq",
										Vector.<String>([	Lang.FloorProp.flooring.@txt,
															Lang.FloorProp.done.@txt]),
										Vector.<Function>([	function():void 
															{
																showFloorTexMenu(function(f:int):void 
																{
																	area.flooring=f;
																	floorPlan.refresh();
																	showFloorAreaProperties(area);
																});
															},
															showFurnitureMenu])));
			}//endfunction
			// ---------------------------------------------------------------------
			function showFurnitureProperties(itm:Item):void
			{
				replaceMenu(new DialogMenu(Lang.FurnitureProp.title.@txt+" : "+getQualifiedClassName(itm.icon),
										Vector.<String>([	Lang.FurnitureProp.rotation.@txt+" = ["+itm.icon.rotation+"]",
															Lang.FurnitureProp.remove.@txt,
															Lang.FurnitureProp.done.@txt]),
										Vector.<Function>([	function(val:String):void		// set rotation
															{
																itm.icon.rotation = Number(val);
															},	
															function():void 
															{
																floorPlan.removeFurniture(itm);
																showFurnitureMenu();
															},
															showFurnitureMenu])));
			}//endfunction
			// ---------------------------------------------------------------------
			function showDoorProperties(door:Door):void
			{
				var wall:Wall = null;
				for (var i:int=floorPlan.Walls.length-1; i>-1; i--)
					if (floorPlan.Walls[i].Doors.indexOf(door)!=-1)
						wall = floorPlan.Walls[i];
				var wallW:Number = wall.joint1.subtract(wall.joint2).length/100;
				replaceMenu(new DialogMenu(Lang.DoorProp.title.@txt+" : "+getQualifiedClassName(door.icon),
										Vector.<String>([	Lang.DoorProp.width.@txt+" = ["+int(Math.abs(door.dir)*wallW*100)/100+"]",
															Lang.DoorProp.flip.@txt,
															Lang.DoorProp.remove.@txt,
															Lang.DoorProp.done.@txt]),
										Vector.<Function>([	function(val:String):void 	// change door length
															{
																if (door.dir<0)
																	door.dir = -Math.min(1,Math.max(0.01,Number(val)/wallW));
																else
																	door.dir = Math.min(1,Math.max(0.01,Number(val)/wallW));
																floorPlan.refresh();
															},
															function():void 			// swap door dir
															{
																door.pivot += door.dir;
																door.dir*=-1;
																floorPlan.refresh();
															},
															function():void 			// remove door
															{
																wall.removeDoor(door);
																floorPlan.drawWall(wall);
																showFurnitureMenu();
															},
															showFurnitureMenu])));		// done
			}//endfunction
			// ---------------------------------------------------------------------
			function showLineProperties(line:Line):void
			{
				replaceMenu(new DialogMenu(Lang.LineProp.title.@txt,
										Vector.<String>([	Lang.LineProp.length.@txt +" = ["+line.joint1.subtract(line.joint2).length+"]",
															Lang.LineProp.thickness.@txt+" = ["+line.thickness+"]",
															Lang.LineProp.color.@txt,
															Lang.LineProp.remove.@txt,
															Lang.LineProp.done.@txt]),
										Vector.<Function>([	function(val:String):void	// set line length
															{
																if (isNaN(parseFloat(val))) return;
																var vec:Point = line.joint2.subtract(line.joint1);
																var dif:Number = parseFloat(val) - vec.length;
																vec.normalize(1);
																line.joint1.x -= vec.x * 0.5 * dif;
																line.joint1.y -= vec.y * 0.5 * dif;
																line.joint2.x += vec.x * 0.5 * dif;
																line.joint2.y += vec.y * 0.5 * dif;
																line.refresh();
															},
															function(val:String):void	// set line thickness
															{
																line.thickness = Number(val);
																line.refresh();
															},
															function():void	// set line color
															{
																showColorMenu(function(color:uint):void 
																{
																	line.color = color;
																	line.refresh();
																	showLineProperties(line);
																});
															},
															function():void 			// remove line
															{
																floorPlan.removeLine(line);
																floorPlan.refresh();
																showFurnitureMenu();
															},
															showFurnitureMenu])));
			}//endfunction
			// ---------------------------------------------------------------------
			function showWallProperties(wall:Wall):void
			{
				replaceMenu(new DialogMenu(Lang.WallProp.title.@txt,
										Vector.<String>([	Lang.WallProp.length.@txt +" = ["+wall.joint1.subtract(wall.joint2).length+"]",
															Lang.WallProp.thickness.@txt +" = ["+wall.thickness+"]",
															Lang.WallProp.edit.@txt,
															Lang.WallProp.remove.@txt,
															Lang.WallProp.done.@txt]),
										Vector.<Function>([	function(val:String):void	// set wall length
															{
																if (isNaN(parseFloat(val))) return;
																var vec:Point = wall.joint2.subtract(wall.joint1);
																var dif:Number = parseFloat(val) - vec.length;
																vec.normalize(1);
																wall.joint1.x -= vec.x * 0.5 * dif;
																wall.joint1.y -= vec.y * 0.5 * dif;
																wall.joint2.x += vec.x * 0.5 * dif;
																wall.joint2.y += vec.y * 0.5 * dif;
																floorPlan.refresh();
															},
															function(val:String):void 	// set wall length
															{
																if (isNaN(parseFloat(val))) return;
																wall.thickness = Math.max(5,Math.min(30,parseFloat(val)));
																floorPlan.refresh();
															},
															function():void				// edit side view
															{
																modeWallSideView(wall);
															},
															function():void 			// remove wall
															{
																floorPlan.removeWall(wall);
																floorPlan.refresh();
																showFurnitureMenu();
															},
															showFurnitureMenu])));
			}//endfunction
			// ---------------------------------------------------------------------
			function showLabelProperties(tf:TextField):void
			{
				replaceMenu(new DialogMenu(Lang.LabelProp.title.@txt,
										Vector.<String>([Lang.LabelProp.size.@txt+" = ["+tf.defaultTextFormat.size+"]",
														Lang.LabelProp.color.@txt+" = "+tf.defaultTextFormat.color.toString(16),
														Lang.LabelProp.remove.@txt,
														Lang.LabelProp.done.@txt]),
										Vector.<Function>([	function(val:String):void 
															{
																var tff:TextFormat = tf.defaultTextFormat;
																tff.size = Number(val);
																tf.defaultTextFormat = tff;
																tf.setTextFormat(tff);
															},
															function():void 
															{
																showColorMenu(function(color:uint):void 
																{
																	var tff:TextFormat = tf.defaultTextFormat;
																	tff.color = color;
																	tf.defaultTextFormat = tff;
																	tf.setTextFormat(tff);
																	showLabelProperties(tf);
																});
															},
															function():void 
															{
																floorPlan.removeLabel(tf);
																showFurnitureMenu();
															},
															showFurnitureMenu])));
			}//endfunction
			// ---------------------------------------------------------------------
			function showColorMenu(callBack:Function):void
			{
				replaceMenu(new ColorMenu(callBack));
			}//endfunction
			// ---------------------------------------------------------------------
			function showFloorTexMenu(callBack:Function):void
			{
				var Icos:Vector.<Sprite> = new Vector.<Sprite>();
				for (var i:int=0; i<floorPlan.FloorPatterns.length; i++)
				{
					var s:Sprite = new Sprite();
					s.addChild(new Bitmap(floorPlan.FloorPatterns[i]));
					Icos.push(s);
				}
				replaceMenu(new IconsMenu(Icos,5,2,callBack));
			}//endfunction
			
			
			
			floorPlan.selected = null;
			
			// ----- default editing logic
			var snapDist:Number = 10;
			var prevMousePt:Point = new Point(0,0);
			stepFn = function():void
			{
				if (mouseDownPt.w>mouseUpPt.w)	// is dragging
				{
					if (floorPlan.selected is Point && floorPlan.Joints.indexOf(floorPlan.selected)!=-1)
					{	// ----- shift joint
						var selJ:Point = (Point)(floorPlan.selected); 
						selJ.x = grid.mouseX;
						selJ.y = grid.mouseY;
						var snapJ:Point = floorPlan.nearestJoint(selJ, snapDist);		// chk if near any joint
						if (snapJ!=null)	// snap end to joint
						{
							if  (snapJ!=selJ)
							{
								floorPlan.replaceJointWith(selJ,snapJ);
								floorPlan.selected = null;
								floorPlan.refresh();
							}
						}
						else	// joint wall end to existing wall
						{
							var snapW:Wall = floorPlan.nearestNonAdjWall(selJ, snapDist);
							if (snapW!=null && snapW.joint1!=selJ && snapW.joint2!=selJ)
							{
								floorPlan.removeWall(snapW);
								floorPlan.createWall(snapW.joint1, selJ);
								floorPlan.createWall(snapW.joint2, selJ);
								floorPlan.selected = null;
								mouseDownPt = new Vector3D(); // stopDrag
							}
						}
						floorPlan.refresh();
					}
					else if (floorPlan.selected is Point)
					{
						var pt:Point = (Point)(floorPlan.selected); 
						pt.x = grid.mouseX;
						pt.y = grid.mouseY;
						floorPlan.refresh();
					}
					else if (floorPlan.selected is Line)
					{	// ----- shift wall
						var line:Line = (Line)(floorPlan.selected);
						line.joint1.x += grid.mouseX - prevMousePt.x;
						line.joint1.y += grid.mouseY - prevMousePt.y;
						line.joint2.x += grid.mouseX - prevMousePt.x;
						line.joint2.y += grid.mouseY - prevMousePt.y;
						line.refresh();
					}
					else if (floorPlan.selected is Wall)
					{	// ----- shift wall
						var selW:Wall = (Wall)(floorPlan.selected);
						selW.joint1.x += grid.mouseX - prevMousePt.x;
						selW.joint1.y += grid.mouseY - prevMousePt.y;
						selW.joint2.x += grid.mouseX - prevMousePt.x;
						selW.joint2.y += grid.mouseY - prevMousePt.y;
						floorPlan.refresh();
					}
					else if (floorPlan.selected is Door)
					{
						floorPlan.refresh();
					}
					else if (floorPlan.selected is TextField)
					{
						floorPlan.selected.x += grid.mouseX - prevMousePt.x;
						floorPlan.selected.y += grid.mouseY - prevMousePt.y;
					}
					else if (floorPlan.selected is Item)
					{	// ----- furniture shifting... 
					}
					else if (floorPlan.selected is FloorArea)
					{	// ----- floor area selected
					}
					else 
					{	// ----- shift grid background
						grid.x += (grid.mouseX - prevMousePt.x)*grid.scaleX;
						grid.y += (grid.mouseY - prevMousePt.y)*grid.scaleY;
						grid.update();
					}
					prevMousePt.x = grid.mouseX;
					prevMousePt.y = grid.mouseY;
				}
			}
			// ----------------------------------------------------------------
			mouseDownFn = function():void
			{
				prevMousePt.x = grid.mouseX;
				prevMousePt.y = grid.mouseY;
				
				floorPlan.mouseSelect();				// chk if anything selected
				
				if (floorPlan.selected!=null)			// save for undo
					undoStk.push(floorPlan.exportData());
				
				if (floorPlan.selected is Point)		// selected a joint
				{
					replaceMenu(null);	// hide all prev menus
				}
				if (floorPlan.selected is Line)		// selected a ruler line
				{
					showLineProperties((Line)(floorPlan.selected));
				}
				else if (floorPlan.selected is Wall)	// selected a wall
				{
					showWallProperties((Wall)(floorPlan.selected));
				}
				else if (floorPlan.selected is Door)	// selected a door
				{
					showDoorProperties((Door)(floorPlan.selected));
				}
				else if (floorPlan.selected is TextField)	// selected a label
				{
					(TextField)(floorPlan.selected).background = true;
					showLabelProperties((TextField)(floorPlan.selected));
				}
				else if (floorPlan.selected is Item)		// selected a furniture
				{
					showFurnitureProperties((Item)(floorPlan.selected));
				}
				else if (floorPlan.selected is FloorArea)		// selected floor area
				{
					showFloorAreaProperties((FloorArea)(floorPlan.selected));
				}
				else
				{
					showFurnitureMenu();
					floorPlan.refresh();
					//prn("floorPlan.selected="+floorPlan.selected+"   "+floorPlan.debugStr);
				}
			}
			// ----------------------------------------------------------------
			mouseUpFn = function():void
			{
				if (floorPlan.selected!=null && floorPlan.selected is TextField) 
					(TextField)(floorPlan.selected).background = false;
				if (undoStk.length>0 && floorPlan.exportData()==undoStk[undoStk.length-1]) 
					undoStk.pop();	// if no state change 
			}
		}//endfunction
		
		//=============================================================================================
		// go into side view of wall
		//=============================================================================================
		private function modeWallSideView(wall:Wall):void
		{
			var ports:XMLList = Lang.Ports[0].port;
			
			var selected:Door = null;
			var ctrls:Sprite = null;
			
			function showSideItemsMenu():void
			{
				wall.updateSideView();
				selected = null;
				ctrls = null;
				replaceMenu(new AddSideViewItemsMenu(ports,function(idx:int):void
				{
					var cls:Class = Class(getDefinitionByName(ports[idx].@side));
					var sideIco:Sprite = new cls();
					cls =  Class(getDefinitionByName(ports[idx].@cls));
					var planIco:Sprite = new cls();
					var door:Door = new Door(0.25, 0.5, planIco, sideIco);
					wall.addDoor(door);
					wall.updateSideView();
					//modeAddDoors(new IcoCls() as Sprite);
				}));	
			}//endfunction
			
			function showDoorMenu(door:Door):void
			{
				var wallW:Number = wall.joint1.subtract(wall.joint2).length;
				replaceMenu(new DialogMenu(Lang.DoorProp.title.@txt+" : "+getQualifiedClassName(door.icon),
									Vector.<String>([	Lang.DoorProp.width.@txt+" = ["+int(Math.abs(door.dir)*wallW*100)/100+"]",
														Lang.DoorProp.height.@txt+" = ["+int(Math.abs(door.height)*wall.height*100)/100+"]",
														Lang.DoorProp.flip.@txt,
														Lang.DoorProp.remove.@txt,
														Lang.DoorProp.done.@txt]),
									Vector.<Function>([	function(val:String):void 	// change door width
														{
															if (door.dir<0)
																door.dir = -Math.min(1,Math.max(0.01,Number(val)/wallW));
															else
																door.dir = Math.min(1,Math.max(0.01,Number(val)/wallW));
															wall.updateSideView();
														},
														function(val:String):void 	// change door height
														{
															door.height = Math.min(1,Math.max(0.01,Number(val)/wall.height));
															wall.updateSideView();
														},
														function():void 			// swap door dir
														{
															door.pivot += door.dir;
															door.dir*=-1;
															wall.updateSideView();
														},
														function():void 			// remove door
														{
															wall.removeDoor(door);
															wall.updateSideView();
															showSideItemsMenu();
														},
														showSideItemsMenu])));		// done
			}
			showSideItemsMenu();
			
			floorPlan.selected = null;
			floorPlan.overlay.visible = false;
			//wall.updateSideView();
			wall.sideView.x = -grid.x + stage.stageWidth / 2;
			wall.sideView.y = -grid.y + stage.stageHeight / 2;
			grid.addChild(wall.sideView);
			topBar.visible = false;
			trace("grid="+grid+"  wall.sideVied.width="+wall.sideView.width);	
			
			function showWallAreaProperties(wall:Wall):void
			{
				replaceMenu(new DialogMenu(Lang.WallProp.area.@txt+":"+int(wall.area/100)/100+"m sq",
										Vector.<String>([	Lang.WallProp.wallPaper.@txt,
															Lang.WallProp.height.@txt+"=["+floorPlan.ceilingHeight+"]",
															Lang.WallProp.done.@txt]),
										Vector.<Function>([	function():void 
															{
																replaceMenu(new ItemsMenu(function(prod:Object):void 
																{
																	// ----- loads the pic for the item
																	var picUrl:String = prod.pic;
																	picUrl = apiUrl+picUrl;
																	if (picUrl.indexOf("http")==-1)	picUrl = "http://"+picUrl;
																	Utils.loadAsset(picUrl,function(pic:DisplayObject):void 
																	{
																		trace(picUrl + "  wallpaperPic = "+pic);
																		wall.wallPaperId = prod.id;
																		
																		var bmd:BitmapData = new BitmapData(pic.width,pic.height);
																		bmd.draw(pic);
																		wall.wallPaper = bmd;
																		wall.updateSideView();
																		showWallAreaProperties(wall);
																	});
																},70,parseInt("10000000",2)));
																/*
																var Icos:Vector.<Sprite> = new Vector.<Sprite>();
																for (var i:int=0; i<Wall.WallPapers.length; i++)
																{
																	var s:Sprite = new Sprite();
																	s.addChild(new Bitmap(Wall.WallPapers[i]));
																	Icos.push(s);
																}
																replaceMenu(new IconsMenu(Icos,5,2,function(f:int):void 
																{
																	wall.wallPaper = Wall.WallPapers[f];
																	wall.updateSideView();
																	showWallAreaProperties(wall);
																}));
																*/
															},
															function(val:String):void 
															{
																floorPlan.ceilingHeight = parseFloat(val)*100;
																if (isNaN(floorPlan.ceilingHeight))
																	floorPlan.ceilingHeight = 200;
																for (var i:int = 0; i < floorPlan.Walls.length; i++ )
																	floorPlan.Walls[i].height = floorPlan.ceilingHeight;
																wall.updateSideView();
															},
															showSideItemsMenu])));
			}//endfunction
			
			var mouseDownPt:Vector3D = null;
			stepFn = function():void
			{
				if (mouseDownPt != null)
				{
					if (ctrls)
					{
						wall.updateDoorWithIconPosn(selected);
					}
					else
					{
						grid.x -= mouseDownPt.x - grid.mouseX;
						grid.y -= mouseDownPt.y - grid.mouseY;
						grid.update();
					}
				}
			}//endfunction
			
			mouseDownFn = function():void
			{
				mouseDownPt = new Vector3D(grid.mouseX, grid.mouseY, 0, getTimer());
				if (ctrls == null)
				{
					selected = null;
					for (var i:int = 0; i < wall.Doors.length && ctrls==null; i++)
						if (wall.Doors[i].sideIcon.hitTestPoint(stage.mouseX, stage.mouseY))
						{
							selected = wall.Doors[i];
							ctrls = floorPlan.furnitureTransformControls(selected.sideIcon,5,false);
							wall.sideView.addChild(ctrls);
						}
				}
				
				if (selected != null)	showDoorMenu(selected);
				else					showSideItemsMenu();
			}//endfunction
			
			mouseUpFn = function():void
			{
				if (mouseDownPt==null) return;
				
				if (ctrls!=null)
				{
					if (!ctrls.hitTestPoint(grid.stage.mouseX, grid.stage.mouseY))
					{
						if (ctrls.parent!=null) 
							ctrls.parent.removeChild(ctrls);
						ctrls = null;
					}
				}
				else if (wall.sideView.hitTestPoint(grid.stage.mouseX, grid.stage.mouseY))
					showWallAreaProperties(wall);
				else if (getTimer()-mouseDownPt.w<200)
				{
					grid.removeChild(wall.sideView);
					topBar.visible = true;
					floorPlan.overlay.visible = true;
					showFurnitureMenu();
					modeDefault();
					floorPlan.refresh();
				}
				mouseDownPt = null;
			}//endfunction
		}//endfunction
		
		//=============================================================================================
		// go into adding lines mode
		//=============================================================================================
		private function modeAddLines(snapDist:Number=10):void
		{
			replaceMenu( new DialogMenu("ADDING LINES",
									Vector.<String>(["DONE"]),
									Vector.<Function>([function():void {showFurnitureMenu(); modeDefault();}])));
			
			// ----------------------------------------------------------------
			var line:Line = null;
			stepFn = function():void
			{
				if (line!=null)
				{
					trace("line ?? "+line);
					line.joint2.x = grid.mouseX;
					line.joint2.y = grid.mouseY;
					floorPlan.refresh();
				}
			}
			// ----------------------------------------------------------------
			mouseDownFn = function():void
			{
				undoStk.push(floorPlan.exportData());
				if (line==null)
				{
					line = floorPlan.createLine(new Point(grid.mouseX,grid.mouseY),
												new Point(grid.mouseX,grid.mouseY));
				}
			}
			// ----------------------------------------------------------------
			mouseUpFn = function():void
			{
				if (line!=null && line.joint1.subtract(line.joint2).length<=snapDist)
				{
					floorPlan.removeLine(line);		// remove line stub
					floorPlan.refresh();
				}
				line = null;
				
				if (undoStk.length>0 && undoStk[undoStk.length-1]==floorPlan.exportData())
					undoStk.pop();
			}
		}//endfunction
		
		//=============================================================================================
		// go into adding walls mode
		//=============================================================================================
		private function modeAddWalls(snapDist:Number=10):void
		{
			replaceMenu( new DialogMenu("ADDING WALLS",
									Vector.<String>(["DONE"]),
									Vector.<Function>([function():void {showFurnitureMenu(); modeDefault();}])));
			
			// ----------------------------------------------------------------
			var wall:Wall = null;
			stepFn = function():void
			{
				if (wall!=null)
				{
					wall.joint2.x = grid.mouseX;
					wall.joint2.y = grid.mouseY;
					
					var snapJ:Point = floorPlan.nearestJoint(wall.joint2, snapDist);		// chk if near any joint
					if (snapJ!=null && snapJ!=wall.joint1)	
					{	// snap to another wall joint
						if  (snapJ!=wall.joint2)
						{
							//prn("modeAddWalls replacingJoint");
							floorPlan.replaceJointWith(wall.joint2,snapJ);
							wall = null;
						}
					}
					else
					{
						var collided:Wall = floorPlan.chkWallCollide(wall);
						if (collided != null)
						{
							var intercept:Point = floorPlan.projectedWallPosition(collided, wall.joint2);
							floorPlan.removeWall(collided);
							floorPlan.createWall(collided.joint1, intercept,snapDist);
							floorPlan.createWall(collided.joint2, intercept, snapDist);
							floorPlan.removeWall(wall);
							floorPlan.createWall(wall.joint1, intercept,snapDist);
							wall = null;
						}
					}
					floorPlan.refresh();
				}
			}
			// ----------------------------------------------------------------
			mouseDownFn = function():void
			{
				undoStk.push(floorPlan.exportData());
				if (wall==null)
				{
					wall = floorPlan.createWall(new Point(grid.mouseX,grid.mouseY),
												new Point(grid.mouseX,grid.mouseY),
												snapDist);
				}
			}
			// ----------------------------------------------------------------
			mouseUpFn = function():void
			{
				if (wall!=null && wall.joint1.subtract(wall.joint2).length<=snapDist)
				{
					floorPlan.removeWall(wall);		// remove wall stub
					floorPlan.refresh();
				}
				wall = null;
				
				if (undoStk.length>0 && undoStk[undoStk.length-1]==floorPlan.exportData())
					undoStk.pop();
			}
		}//endfunction
		
		//=============================================================================================
		// go into adding doors mode
		//=============================================================================================
		private function modeAddDoors(ico:Sprite,sideIco:Sprite,snapDist:Number=10):void
		{
			replaceMenu(new DialogMenu("ADDING DOORS",
										Vector.<String>(["DONE"]),
										Vector.<Function>([function():void {showDoorsMenu(); modeDefault();}])));
			
			// ----- add doors logic
			var icoW:int = ico.width;
			var prevWall:Wall = null;
			var door:Door = new Door(0,0.5,ico,sideIco);	// pivot and dir values to be replaced
			
			stepFn = function():void
			{
				// ----- remove added display door
				if (prevWall!=null)
				{	
					if (prevWall.Doors.indexOf(door)!=-1)
						prevWall.Doors.splice(prevWall.Doors.indexOf(door),1);
					floorPlan.drawWall(prevWall);
				}
				
				var mouseP:Point = new Point(grid.mouseX,grid.mouseY);
				
				var near:Wall = floorPlan.nearestNonAdjWall(mouseP,snapDist);
				var doorP:Point = null;
				if (near!=null)	
				{
					doorP = near.chkPlaceDoor(mouseP, icoW);	// chk place door of 100 width
				}
				// ----- if in position to place door
				//prn("near="+near+"  doorP="+doorP)
				if (near!=null && doorP!=null)
				{
					door.pivot = doorP.x;
					door.dir = icoW/(near.joint2.subtract(near.joint1).length);	// calculate ratio of occupied wall
					near.addDoor(door);
					floorPlan.drawWall(near);
					prevWall = near;
				}
				
				// ----- hack to prevent immediate mouseUp
				mouseUpFn = function():void
				{
					modeDefault();
					showDoorsMenu();
				}
			}//endfunction
			mouseDownFn = function():void
			{
				
			}
			
		}//endfunction
		
		//=============================================================================================
		// convenience function to place new menu on stage in place of existing menu
		//=============================================================================================
		private function replaceMenu(nmenu:Sprite,px:int=-1,py:int=-1) : void
		{
			if (px==-1) px = stage.stageWidth;
			if (py==-1) py = topBar.height+5;
			if (menu!=null)
			{
				if (menu.parent!=null) menu.parent.removeChild(menu);
				px = menu.x;
				py = menu.y;
			}
			if (nmenu == null) return;
			menu = nmenu;
			menu.x = Math.min(px,stage.stageWidth-menu.width-5);
			menu.y = Math.min(py,stage.stageHeight-menu.height-5);
			stage.addChild(menu);
		}//endfunction
		
		//=============================================================================================
		// returns whether door of width can be placed at position pt along given wall 
		//=============================================================================================
		private function chkPlaceDoor(wall:Wall, pt:Point, width:Number):Point
		{
			var wallV:Point = wall.joint2.subtract(wall.joint1);
			var wallL:Number = wallV.length;
			wallV.normalize(1);
			var proj:Number = (pt.x-wall.joint1.x)*wallV.x + (pt.y-wall.joint1.y)*wallV.y;	// ratio along wall where door is at
			var a:Number = proj/wallL-0.5*width/wallL;	// door span along wallL
			var b:Number = proj/wallL+0.5*width/wallL;
			if (a<0 || b>1)	return null;	//exceed wall limit
			
			for (var i:int=wall.Doors.length-1; i>-1; i--)		// check if overlap other doors
			{
				var c:Number = wall.Doors[i].pivot;
				var d:Number = wall.Doors[i].dir+c;
				if (d<c)
				{
					var tmp:Number = d;
					d = c;
					c = tmp;
				}
				if ((a>c && a<d) || (b>c && b<d))
					return null;
			}
			return new Point(a,b);
		}//endfunction
		
		//=============================================================================================
		// Main Loop
		//=============================================================================================
		private function onEnterFrame(ev:Event):void
		{
			if (stepFn!=null) stepFn();
		}//endfunction
		
		//=============================================================================================
		//
		//=============================================================================================
		private function onMouseDown(ev:Event):void
		{
			if (topBar!=null && topBar.hitTestPoint(stage.mouseX,stage.mouseY)) return;
			if (menu!=null && menu.hitTestPoint(stage.mouseX,stage.mouseY)) return;
			if (scaleSlider!=null && scaleSlider.hitTestPoint(stage.mouseX,stage.mouseY)) return;
			
			mouseDownPt = new Vector3D(grid.mouseX,grid.mouseY,0,getTimer());
			if (mouseDownFn!=null) mouseDownFn();
		}//endfunction
		
		//=============================================================================================
		//
		//=============================================================================================
		private function onMouseUp(ev:Event):void
		{
			mouseUpPt = new Vector3D(grid.mouseX,grid.mouseY,0,getTimer());
			if (mouseUpFn!=null) mouseUpFn();
		}//endfunction
		
		//=============================================================================================
		// debug printout function
		//=============================================================================================
		private var debugTf:TextField;
		private function prn(s:String):void
		{
			if (debugTf==null)
			{
				debugTf = new TextField();
				debugTf.autoSize = "left";
				debugTf.wordWrap = false;
				//debugTf.mouseEnabled = false;
				var tff:TextFormat = debugTf.defaultTextFormat;
				tff.color = 0x000000;
				tff.font = "arial";
				tff.size = 11;
				debugTf.defaultTextFormat = tff;
				debugTf.text = "";
				addChild(debugTf);
			}
		
			debugTf.appendText(s+"\n");
		}//endfunction
		
		//=============================================================================================
		// creates a vertical slider bar of wxh dimensions  
		//=============================================================================================
		private function createVSlider(markings:Array,callBack:Function):Sprite
		{
			var w:int = 5;
			var h:int = 200;
			
			// ----- main sprite
			var s:Sprite = new Sprite();
			s.graphics.beginFill(0xCCCCCC,1);
			s.graphics.drawRect(0,0,w,h);
			s.graphics.endFill();
		
			// ----- slider knob
			var slider:Sprite = new Sprite();
			slider.graphics.beginFill(0xEEEEEE,1);
			slider.graphics.drawCircle(0,0,w);
			slider.graphics.endFill();
			slider.graphics.beginFill(0x333333,1);
			slider.graphics.drawCircle(0,0,w/2);
			slider.graphics.endFill();
			slider.buttonMode = true;
			slider.mouseChildren = false;
			slider.filters = [new DropShadowFilter(2)];
			slider.x = w/2;
			slider.y = h/2;
			s.addChild(slider);
		
			// ----- draw markings
			s.graphics.lineStyle(0,0xCCCCCC,1);
			var n:int = markings.length;
			for (var i:int=0; i<n; i++)
			{
				s.graphics.moveTo(w/2,h/(n-1)*i);
				s.graphics.lineTo(w*3/2,h/(n-1)*i);
				var tf:TextField = new TextField();
				var tff:TextFormat = tf.defaultTextFormat;
				tff.color = 0x999999;
				tf.defaultTextFormat = tff;
				tf.text = markings[i];
				tf.autoSize = "left";
				tf.wordWrap = false;
				tf.selectable = false;
				tf.x = w*2;
				tf.y = h/(n-1)*(n-1-i)-tf.height/2;
				s.addChild(tf);
			}
		
			function updateHandler(ev:Event):void
			{
				if (callBack!=null) callBack(1-slider.y/h);
			}
			function startDragHandler(ev:Event):void
			{
				if (slider.hitTestPoint(stage.mouseX,stage.mouseY))
					slider.startDrag(false,new Rectangle(slider.x,0,0,h));
				else
					s.startDrag();
				stage.addEventListener(Event.ENTER_FRAME,updateHandler);
				stage.addEventListener(MouseEvent.MOUSE_UP,stopDragHandler);
			}
			function stopDragHandler(ev:Event):void
			{
				s.stopDrag();
				slider.stopDrag();
				stage.removeEventListener(Event.ENTER_FRAME,updateHandler);
				stage.removeEventListener(MouseEvent.MOUSE_UP,stopDragHandler);
			}
			s.addEventListener(MouseEvent.MOUSE_DOWN,startDragHandler);
		
			return s;
		}//endfunction
		
		//=============================================================================================
		//
		//=============================================================================================
		private function createDirCompass():Sprite
		{
			var s:Sprite = new Sprite();
			s.graphics.beginFill(0xFFFFFF,1);
			s.graphics.drawCircle(0,0,30);
			s.graphics.endFill();
			
			return s;
		}//endfunction
	}//endclass
}//endpackage

import com.adobe.images.JPGEncoder;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.DisplayObject;
import flash.display.JointStyle;
import flash.display.Loader;
import flash.display.MovieClip;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.events.FocusEvent;
import flash.events.IOErrorEvent;
import flash.filters.DropShadowFilter;
import flash.filters.GlowFilter;
import flash.geom.ColorTransform;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.geom.Vector3D;
import flash.net.SharedObject;
import flash.net.URLLoader;
import flash.net.URLVariables;
import flash.net.URLRequest;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.utils.ByteArray;
import flash.utils.getDefinitionByName;
import flash.utils.getQualifiedClassName;
import flash.utils.getTimer;
import mx.utils.Base64Encoder;
import mx.utils.Base64Decoder;

class FloatingMenu extends Sprite		// to be extended
{
	protected var Btns:Vector.<Sprite> = null;
	protected var callBackFn:Function = null;
	protected var overlay:Sprite = null;			// something on top to disable this
	protected var mouseDownPt:Point = null;
	protected var draggable:Boolean = true;
	
	//===============================================================================================
	// simpleton constructor, subclasses must initialize Btns and callBackFn
	//===============================================================================================
	public function FloatingMenu():void
	{
		filters = [new DropShadowFilter(4,90,0x000000,1,4,4,0.5)];
		addEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
		addEventListener(MouseEvent.MOUSE_UP,onMouseUp);
		addEventListener(Event.REMOVED_FROM_STAGE,onRemove);
		addEventListener(Event.ENTER_FRAME,onEnterFrame);
		addEventListener(MouseEvent.MOUSE_OUT,onMouseUp);
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	protected function onMouseDown(ev:Event):void
	{
		if (stage==null) return;
		trace("mouseDown!!");
		mouseDownPt = new Point(this.mouseX,this.mouseY);
		if (draggable)	this.startDrag();
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	protected function onMouseUp(ev:Event):void
	{
		if (stage==null) return;
		this.stopDrag();
		if (overlay!=null) return;
		if (mouseDownPt==null)	return;	// mousedown somewhere else
		if (mouseDownPt.subtract(new Point(this.mouseX,this.mouseY)).length>10) return;	// is dragging
		mouseDownPt = null;
		if (Btns!=null)
		{
			trace("Chking for Btns Pressed");
		for (var i:int=Btns.length-1; i>-1; i--)
			if (Btns[i].parent==this && Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
			{
				trace("Btn "+i+"pressed!");
				if  (callBackFn!=null) callBackFn(i);	// exec callback function
				return;
			}
		}
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	protected function onEnterFrame(ev:Event):void
	{
		if (overlay!=null && overlay.parent!=this) overlay=null;
		if (stage==null) return;
		
		var A:Array = null;
		
		if (Btns!=null)
		for (var i:int=Btns.length-1; i>-1; i--)
			if (overlay==null && Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
			{
				A = Btns[i].filters;
				if (A.length==0)
					Btns[i].filters=[new GlowFilter(0x000000,1,4,4,1)];
				else if ((GlowFilter)(A[0]).strength<1)
					(GlowFilter)(A[0]).strength+=0.1;
			}
			else
			{
				if (Btns[i].filters.length>0)
				{
					A = Btns[i].filters;
					if (A.length>0 && (GlowFilter)(A[0]).strength>0)
						(GlowFilter)(A[0]).strength-=0.1;
					else 
						A = null;
					Btns[i].filters = A;
				}
			}
		
		// ----- ensure menu within stage bounds
		if (this.x+this.width>this.stage.stageWidth)	this.x = this.stage.stageWidth-this.width;
		if (this.y+this.height>this.stage.stageHeight)	this.y = this.stage.stageHeight-this.height;
		if (this.x<0)	this.x = 0;
		if (this.y<0)	this.y = 0;
		
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	protected function onRemove(ev:Event):void
	{
		removeEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
		removeEventListener(MouseEvent.MOUSE_UP,onMouseUp);
		removeEventListener(Event.REMOVED_FROM_STAGE,onRemove);
		removeEventListener(Event.ENTER_FRAME,onEnterFrame);
		removeEventListener(MouseEvent.MOUSE_OUT,onMouseUp);
	}//endfunction
	
	//===============================================================================================
	// draws a striped rectangle in given sprite 
	//===============================================================================================
	public static function drawStripedRect(s:Sprite,x:Number,y:Number,w:Number,h:Number,c1:uint,c2:uint,rnd:uint=10,sw:Number=5,rot:Number=Math.PI/4) : Sprite
	{
		if (s==null)	s = new Sprite();
		var mat:Matrix = new Matrix();
		mat.createGradientBox(sw,sw,rot,0,0);
		s.graphics.beginGradientFill("linear",[c1,c2],[1,1],[127,128],mat,"repeat");
		s.graphics.drawRoundRect(x,y,w,h,rnd,rnd);
		s.graphics.endFill();
		
		return s;
	}//endfunction 
}//endclass

class IconsMenu extends FloatingMenu	
{
	private var pageIdx:int=0;
	private var pageBtns:Sprite = null;
	private var r:int = 1;		// rows
	private var c:int = 1;		// cols
	private var bw:int = 50;	// btn width
	private var bh:int = 50;	// btn height
	private var marg:int = 10;
	
	//===============================================================================================
	// 
	//===============================================================================================
	public function IconsMenu(Icos:Vector.<Sprite>,rows:int,cols:int,callBack:Function):void
	{
		Btns = Icos;
		callBackFn = callBack;
	
		if (rows<1)	rows = 1;
		if (cols<1) cols = 1;
		r = rows;
		c = cols;
		pageBtns = new Sprite();
		addChild(pageBtns);
		
		refresh();
		
		function pageBtnsClickHandler(ev:Event) : void
		{
			for (var i:int=pageBtns.numChildren-1; i>-1; i--)
				if (pageBtns.getChildAt(i).hitTestPoint(stage.mouseX,stage.mouseY))
					pageTo(i);
		}
		function pageBtnsRemoveHandler(ev:Event) : void
		{
			pageBtns.removeEventListener(MouseEvent.CLICK,pageBtnsClickHandler);
			pageBtns.removeEventListener(Event.REMOVED_FROM_STAGE,pageBtnsRemoveHandler);
		}
		
		pageBtns.addEventListener(MouseEvent.CLICK,pageBtnsClickHandler);
		pageBtns.addEventListener(Event.REMOVED_FROM_STAGE,pageBtnsRemoveHandler);
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	public function refresh():void
	{
		var tw:int=0;
		var th:int=0;
		for (var i:int=Btns.length-1; i>-1; i--)
		{
			tw+=Btns[i].width;
			th+=Btns[i].height;
		}
		if (tw>0)	bw = tw/Btns.length;
		if (th>0)	bh = th/Btns.length;
		
		// ----- update pageBtns to show correct pages
		var pageCnt:int = Math.ceil(Btns.length/(r*c));
		while (pageBtns.numChildren>pageCnt)	
			pageBtns.removeChildAt(pageBtns.numChildren-1);
		for (i=0; i<pageCnt; i++)
		{
			var sqr:Sprite = new Sprite();
			sqr.graphics.beginFill(0x666666,1);
			sqr.graphics.drawRect(0,0,9,9);
			sqr.graphics.endFill();
			sqr.x = i*(sqr.width+10);
			sqr.buttonMode = true;
			pageBtns.addChild(sqr);
		}
		
		if (pageCnt>1)
		{
			pageBtns.visible=true;
			drawStripedRect(this,0,0,(bw+marg)*c+marg*3,(bh+marg)*r+marg*3+marg*2,0xFFFFFF,0xF6F6F6,20,10);
		}
		else
		{
			pageBtns.visible=false;
			drawStripedRect(this,0,0,(bw+marg)*c+marg*3,(bh+marg)*r+marg*3,0xFFFFFF,0xF6F6F6,20,10);
		}
		pageBtns.x = (this.width-pageBtns.width)/2;
		pageBtns.y =this.height-marg*2-pageBtns.height/2;
		
		pageTo(pageIdx);
	}//endfunction
	
	//===============================================================================================
	// go to page number
	//===============================================================================================
	public function pageTo(idx:int):void
	{
		while (numChildren>1)	removeChildAt(1);	// child 0 is pageBtns
		
		if (idx<0)	idx = 0;
		if (idx>Math.ceil(Btns.length/(r*c)))	idx = Math.ceil(Btns.length/(r*c));
		var a:int = idx*r*c;
		var b:int = Math.min(Btns.length,a+r*c);
		for (var i:int=a; i<b; i++)
		{
			var btn:Sprite = Btns[i];
			btn.x = marg*2+(i%c)*(bw+marg)+(bw-btn.width)/2;
			btn.y = marg*2+int((i-a)/c)*(bh+marg)+(bh-btn.height)/2;
			addChild(btn);
		}
		
		for (i=pageBtns.numChildren-1; i>-1; i--)
		{
			if (i==idx)
				pageBtns.getChildAt(i).transform.colorTransform = new ColorTransform(1,1,1,1,70,70,70);
			else
				pageBtns.getChildAt(i).transform.colorTransform = new ColorTransform();
		}
		pageIdx = idx;
	}//endfunction	
}//endclass

class TopBarMenu extends FloatingMenu
{
	//===============================================================================================
	// 
	//===============================================================================================
	public function TopBarMenu(labels:XMLList,callBack:Function):void
	{
		draggable = false;
		callBackFn = callBack;
		
		// ----- create buttons
		Btns = new Vector.<Sprite>();
		var n:int = labels.length();
		for (var i:int=0; i<n; i++)
		{
			var tf:TextField = new TextField();
			tf.autoSize = "left";
			tf.wordWrap = false;
			var tff:TextFormat  = tf.defaultTextFormat;
			tff.font = "arial";
			tff.size = 12;
			tff.color = 0x888888;
			tf.defaultTextFormat = tff;
			tf.text = labels[i].@txt;
			var b:Sprite = new Sprite();
			if (getDefinitionByName(labels[i].@ico)!=null)
			{
				var ico:Sprite = new (Class(getDefinitionByName(labels[i].@ico)))();
				tf.x = ico.width+5;
				b.addChild(ico);
			}
			b.addChild(tf);
			b.buttonMode = true;
			b.mouseChildren = false;
			Btns.push(b);
			addChild(b);
		}
		
		// ----- draw btn bodies
		for (i=0; i<n; i++)
		{
			var btn:Sprite = Btns[i];
			var cW:int = btn.width;
			btn.graphics.beginFill(0xEEEEEE,1);
			btn.graphics.drawRoundRect(0,0,btn.width+10,btn.height,10,10);
			btn.graphics.endFill();
			for (var j:int=btn.numChildren-1; j>-1; j--)
			{
				var e:DisplayObject = btn.getChildAt(j);
				e.y = (btn.height-e.height)/2;
				e.x+=5;
			}
		}
		
		// ----- aligning btns
		var hh:int = this.height;
		var offX:int=20;
		for (i=0; i<n; i++)
		{
			var c:DisplayObject = this.getChildAt(i);
			c.x = offX;
			c.y = (hh+10-c.height)/2;
			offX += c.width+20;
			var lin:Sprite = new Sprite();
			lin.graphics.lineStyle(0,0x888888);
			lin.graphics.lineTo(0,hh*0.8);
			lin.x = offX-10;
			lin.y = (hh+10-lin.height)/2;
			addChild(lin);
		}
			
		var ppp:Sprite = this;
		function onResize(ev:Event):void
		{
			ppp.graphics.clear();
			drawStripedRect(ppp,0,0,stage.stageWidth,ppp.height+10,0xFFFFFF,0xF6F6F6,0,10);
		}
		function onAddedToStage(ev:Event):void
		{
			drawStripedRect(ppp,0,0,stage.stageWidth,ppp.height+10,0xFFFFFF,0xF6F6F6,0,10);
			ppp.removeEventListener(Event.ADDED_TO_STAGE,onAddedToStage);
			stage.addEventListener(Event.RESIZE,onResize);
		}
		ppp.addEventListener(Event.ADDED_TO_STAGE,onAddedToStage);
	}//endfunction
}//endclass

class DialogMenu extends FloatingMenu
{
	private var Fns:Vector.<Function> = null;
	private var titleTf:TextField = null;

	//===============================================================================================
	// 
	//===============================================================================================
	public function DialogMenu(title:String,labels:Vector.<String>,callBacks:Vector.<Function>):void
	{
		Fns = callBacks;
		
		// ----- create title
		titleTf = Utils.createText(title, 12, 0x888888);
		addChild(titleTf);
		
		// ----- create buttons
		Btns = new Vector.<Sprite>();
		var n:int = Math.min(labels.length,callBacks.length);
		for (var i:int=0; i<n; i++)
		{
			var lab:String = labels[i];
			var b:Sprite = new Sprite();
			var tf:TextField = Utils.createText(lab,14,0x888888);
			b.addChild(tf);
			b.buttonMode = true;
			b.mouseChildren = false;
			Btns.push(b);
			addChild(b);
		}
		
		// ----- aligning
		var w:int = this.width+20;
		for (i=0; i<Btns.length; i++)
		{
			var btn:Sprite = Btns[i];
			var cW:int = btn.width;
			btn.graphics.beginFill(0xEEEEEE,1);
			btn.graphics.drawRoundRect(0,0,w,btn.height,10,10);
			btn.graphics.endFill();
			for (var j:int=0; j<btn.numChildren; j++)
				btn.getChildAt(j).x += (w-cW)/2;
		}
		var offY:int=20;
		for (i=0; i<this.numChildren; i++)
		{
			var c:DisplayObject = this.getChildAt(i);
			c.y = offY;
			c.x = (w-c.width)/2+10;
			offY += c.height+5;
		}
		drawStripedRect(this,0,0,w+20,this.height+40,0xFFFFFF,0xF6F6F6,20,10);
		
		callBackFn = function(idx:int):void
		{
			if (labels[idx].indexOf("[")!=-1 && labels[idx].indexOf("]")!=-1)
			{
				if (Btns[idx].numChildren == 1)
				{
					trace("create itf");
					var tf:TextField = Btns[idx].getChildAt(0) as TextField;
					tf.text = tf.text.split("=")[0];
					var val:String = labels[idx].split("[")[1].split("]")[0];
					var itf:TextField = Utils.createInputText(function():void 
					{
						itf.parent.removeChild(itf);
						Btns[idx].mouseEnabled = false;
						tf.text = tf.text + "=[" + itf.text + "]";
						Fns[idx](itf.text);
					},
					val);
					itf.width = Btns[idx].width;
					itf.x = this.x + Btns[idx].x + tf.x + tf.width + 5;
					itf.y = this.y + Btns[idx].y;
					this.parent.addChild(itf);
					this.stage.focus = itf;
					Btns[idx].mouseEnabled = true;
				}
			}
			else
				Fns[idx]();	// exec callback function
		}//endfunction
	}//endfunction
}//endclass

class ItemsMenu extends FloatingMenu	
{
	var tabs:Sprite = null;
	
	private var productsData:Array = [];
	private var pageIdx:int=0;
	private var pageBtns:Sprite = null;
	private var r:int = 1;		// rows
	private var c:int = 1;		// cols
	private var bw:int = 50;	// btn width
	private var bh:int = 50;	// btn height
	private var marg:int = 10;
	
	//===============================================================================================
	// 
	//===============================================================================================
	public function ItemsMenu(callBack:Function,icoW:int=70,flags:uint=127):void
	{
		Btns = new Vector.<Sprite>();
		r = 4;
		c = 2;
		pageBtns = new Sprite();
		addChild(pageBtns);
		callBackFn = function (idx:int):void 
		{
			trace("ItemsMenu callback idx:"+idx+"  item data = "+Utils.prnObject(productsData[idx]));
			callBack(productsData[idx]);
		};		
		
		function pageBtnsClickHandler(ev:Event) : void
		{
			for (var i:int=pageBtns.numChildren-1; i>-1; i--)
				if (pageBtns.getChildAt(i).hitTestPoint(stage.mouseX,stage.mouseY))
					pageTo(i);
		}
		function pageBtnsRemoveHandler(ev:Event) : void
		{
			pageBtns.removeEventListener(MouseEvent.CLICK,pageBtnsClickHandler);
			pageBtns.removeEventListener(Event.REMOVED_FROM_STAGE,pageBtnsRemoveHandler);
		}
		pageBtns.addEventListener(MouseEvent.CLICK,pageBtnsClickHandler);
		pageBtns.addEventListener(Event.REMOVED_FROM_STAGE,pageBtnsRemoveHandler);
		
		// ----- LOADS THE FURNITURE DATA AND CREATE CATEGORY TABS
		var ldr:URLLoader = new URLLoader(new URLRequest(FloorPlanner.apiUrl + "?n=api&c=product&m=qd&a=product&productids=047431,047551,047549,047550,047503,047496,J042433,J044554,047419,047422,042418,028710,022182,044209,045398&token=" + FloorPlanner.userToken));
		function onComplete(ev:Event):void
		{
			var dat:Object = JSON.parse(ldr.data);
			trace("GOT FURNITURE LIST :  ldr.data : "+Utils.prnObject(dat));
			
			function createCatLoadFn(prodObj:Object):Function
			{
				return function():void
				{
					var A:Array = [];
					for (var prodid:* in prodObj)
						A.push(prodObj[prodid]);
					showProductCatMenu(A);
				}
			}//endfunction
			
			// ----- generate all the categories
			var AllProducts:Array = [];
			var CatNames:Vector.<String> = Vector.<String>(["全部"]);
			var LoadCatFns:Vector.<Function> = Vector.<Function>([function():void {showProductCatMenu(AllProducts);}]);
			var flagIdx:int=1;
			for (var catid:* in dat.products)
			{
				if (((1<<flagIdx) & flags)>0)
				{
				//	trace("((1<<flagIdx) & flags) = "+((1<<flagIdx) & flags))
					var catData:Object = dat.products[catid];
					CatNames.push(catData.catename+"");					// category name
					LoadCatFns.push(createCatLoadFn(catData.product));	// category load function
					//trace("Category:"+catData.catename+" id:"+catData.cateid+" sn:"+catData.catesn);
					for (var prodid:* in catData.product)
					{
						var prodData:Object = catData.product[prodid];
						//trace("  Product:"+prodData.productname+" sn:"+prodData.productsn);
						AllProducts.push(prodData);
					}
				}
				flagIdx++;
			}
			if ((flags&1)==0 || CatNames.length==2)
			{
				CatNames.shift();
				LoadCatFns.shift();
			}
			
			tabs = Utils.createTabs(CatNames,LoadCatFns);
			addChild(tabs);
			showProductCatMenu(AllProducts);
		}//endfunction
		ldr.addEventListener(Event.COMPLETE,onComplete);
	}//endfunction
	
	//===============================================================================================
	// show the category tabs for 
	//===============================================================================================
	private function showProductCatMenu(prod:Array):void
	{
		//trace("showProductCatMenu("+prod+")");
		
		productsData = prod;
		
		pageIdx = 0;
		function createIco(o:Object):Sprite 
		{
			var s:Sprite = new Sprite();
			//trace("create icon for "+Utils.prnObject(o));
			var bmp:Bitmap = new Bitmap(new BitmapData(70,60,false,0x999999));
			s.addChild(bmp);
			var tf:TextField = Utils.createText(o.productname,12,0x000000,bmp.width);
			tf.x = (bmp.width-tf.width)/2;
			tf.y = bmp.height;
			s.addChild(tf);
			
			Utils.loadJson(FloorPlanner.apiUrl+"?n=api&a=product&c=product&m=class_detail&id="+o.classid+"&token="+ FloorPlanner.userToken, function(od:Object):void 
			{
				for (var atr:* in od.product)	o[atr] = od.product[atr];	// write product details into main product info object
				var picUrl:String = FloorPlanner.apiUrl+o.pic+"";
				if (od.product.modelpics!=null)
				{
					if (o.modelpics is String)	o.modelpics = JSON.parse(o.modelpics);
					picUrl = FloorPlanner.apiUrl+o.modelpics.up;
				}
				trace("create Ico, product obj with details : \n"+Utils.prnObject(o));
				if (picUrl.indexOf("http")==-1)	picUrl = "http://"+picUrl;
				Utils.loadAsset(picUrl,function (pic:DisplayObject):void
				{
					if (pic!=null)
					{
						var bw:int = bmp.bitmapData.width;
						var bh:int = bmp.bitmapData.height;
						var sc:Number = Math.min(bw/pic.width,bh/pic.height);
						bmp.bitmapData.draw(pic,new Matrix(sc,0,0,sc,(bw-pic.width*sc)/2,(bh-pic.height*sc)/2));
					}
				});
			});
			return s;
		}//endfunction
		
		var Icos:Vector.<Sprite> = new Vector.<Sprite>();
		for (var i:int=0; i<prod.length; i++)
		{
			Icos.push(createIco(prod[i]));
		}//endfor
		
		Btns = Icos;
		refresh();
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	public function refresh():void
	{
		var tw:int=0;
		var th:int=0;
		for (var i:int=Btns.length-1; i>-1; i--)
		{
			tw+=Btns[i].width;
			th+=Btns[i].height;
		}
		if (tw>0)	bw = tw/Btns.length;
		if (th>0)	bh = th/Btns.length;
		
		// ----- update pageBtns to show correct pages
		var pageCnt:int = Math.ceil(Btns.length/(r*c));
		while (pageBtns.numChildren>pageCnt)	
			pageBtns.removeChildAt(pageBtns.numChildren-1);
		for (i=0; i<pageCnt; i++)
		{
			var sqr:Sprite = new Sprite();
			sqr.graphics.beginFill(0x666666,1);
			sqr.graphics.drawRect(0,0,9,9);
			sqr.graphics.endFill();
			sqr.x = i*(sqr.width+10);
			sqr.buttonMode = true;
			pageBtns.addChild(sqr);
		}
		
		if (pageCnt>1)
		{
			pageBtns.visible=true;
			drawStripedRect(this,tabs.width+2,0,(bw+marg)*c+marg*3,(bh+marg)*r+marg*3+marg*2,0xFFFFFF,0xF6F6F6,20,10);
		}
		else
		{
			pageBtns.visible=false;
			drawStripedRect(this,tabs.width+2,0,(bw+marg)*c+marg*3,(bh+marg)*r+marg*3,0xFFFFFF,0xF6F6F6,20,10);
		}
		pageBtns.x = (this.width-pageBtns.width)/2;
		pageBtns.y =this.height-marg*2-pageBtns.height/2;
		
		pageTo(pageIdx);
	}//endfunction
	
	//===============================================================================================
	// go to page number
	//===============================================================================================
	public function pageTo(idx:int):void
	{
		while (numChildren>2)	removeChildAt(2);	// child 0 is pageBtns 1 is tabs
		
		if (idx<0)	idx = 0;
		if (idx>Math.ceil(Btns.length/(r*c)))	idx = Math.ceil(Btns.length/(r*c));
		var a:int = idx*r*c;
		var b:int = Math.min(Btns.length,a+r*c);
		for (var i:int=a; i<b; i++)
		{
			var btn:Sprite = Btns[i];
			btn.x = marg*2+(i%c)*(bw+marg)+(bw-btn.width)/2 + tabs.width+2;
			btn.y = marg*2+int((i-a)/c)*(bh+marg)+(bh-btn.height)/2;
			addChild(btn);
		}
		
		for (i=pageBtns.numChildren-1; i>-1; i--)
		{
			if (i==idx)
				pageBtns.getChildAt(i).transform.colorTransform = new ColorTransform(1,1,1,1,70,70,70);
			else
				pageBtns.getChildAt(i).transform.colorTransform = new ColorTransform();
		}
		pageIdx = idx;
	}//endfunction	
	
}//endclass

class AddFurnitureMenu extends IconsMenu
{
	private var IcoCls:Vector.<Class> = null;
	
	//===============================================================================================
	// 
	//===============================================================================================
	public function AddFurnitureMenu(dat:XMLList,callBackFn:Function,icoW:int=70):void
	{
		Btns = new Vector.<Sprite>();
		IcoCls = new Vector.<Class>();
		
		for (var i:int=0; i<dat.length(); i++)
		{
			var btn:Sprite = new Sprite();
			btn.graphics.beginFill(0xFFFFFF,1);
			btn.graphics.drawRoundRect(0,0,icoW,icoW,icoW/10,icoW/10);
			btn.graphics.endFill();
			IcoCls.push(getDefinitionByName(dat[i].@cls));
			var ico:Sprite = new IcoCls[i]();
			if (ico is MovieClip)	(MovieClip)(ico).gotoAndStop(1);
			var bnds:Rectangle = ico.getBounds(ico);
			var sc:Number = Math.min(icoW*0.8/ico.width,icoW*0.8/ico.height);
			ico.scaleX = ico.scaleY = sc;
			ico.x = (icoW-ico.width)/2 - bnds.left*sc;
			ico.y = (icoW-ico.height)/2 - bnds.top*sc;
			btn.addChild(ico);
			btn.buttonMode = true;
			btn.mouseChildren = false;
			var tf:TextField = new TextField();
			tf.autoSize = "left";
			tf.wordWrap = false;
			do {
				var tff:TextFormat = tf.defaultTextFormat;
				tff.color = 0x000000;
				tff.size = int(tff.size)-1;
				tf.defaultTextFormat = tff;
				tf.text = dat[i].@txt;
			}
			while (tf.width>icoW);
			tf.y = btn.height;
			tf.x = (btn.width-tf.width)/2;
			btn.addChild(tf);
			Btns.push(btn);
		}
		
		super(Btns,3,2,callBackFn);		// menu of 3 rows by 2 cols
	}//endfunction
}//endclass

class AddSideViewItemsMenu extends IconsMenu
{
	private var IcoCls:Vector.<Class> = null;
	
	//===============================================================================================
	// 
	//===============================================================================================
	public function AddSideViewItemsMenu(dat:XMLList,callBackFn:Function,icoW:int=70):void
	{
		Btns = new Vector.<Sprite>();
		IcoCls = new Vector.<Class>();
		
		for (var i:int=0; i<dat.length(); i++)
		{
			var btn:Sprite = new Sprite();
			btn.graphics.beginFill(0xFFFFFF,1);
			btn.graphics.drawRoundRect(0,0,icoW,icoW,icoW/10,icoW/10);
			btn.graphics.endFill();
			IcoCls.push(getDefinitionByName(dat[i].@side));
			var ico:Sprite = new IcoCls[i]();
			if (ico is MovieClip)	(MovieClip)(ico).gotoAndStop(1);
			var bnds:Rectangle = ico.getBounds(ico);
			var sc:Number = Math.min(icoW*0.8/ico.width,icoW*0.8/ico.height);
			ico.scaleX = ico.scaleY = sc;
			ico.x = (icoW-ico.width)/2 - bnds.left*sc;
			ico.y = (icoW-ico.height)/2 - bnds.top*sc;
			btn.addChild(ico);
			btn.buttonMode = true;
			btn.mouseChildren = false;
			var tf:TextField = new TextField();
			tf.autoSize = "left";
			tf.wordWrap = false;
			do {
				var tff:TextFormat = tf.defaultTextFormat;
				tff.color = 0x000000;
				tff.size = int(tff.size)-1;
				tf.defaultTextFormat = tff;
				tf.text = dat[i].@txt;
			}
			while (tf.width>icoW);
			tf.y = btn.height;
			tf.x = (btn.width-tf.width)/2;
			btn.addChild(tf);
			Btns.push(btn);
		}
		
		super(Btns,3,2,callBackFn);		// menu of 3 rows by 2 cols
	}//endfunction
}//endclass

class SaveLoadMenu extends IconsMenu
{
	private var floorPlan:FloorPlan;
	private var hasInit:Boolean = false;
	private var showBuildDefaultRoom:Function = null;
	
	private var saveData:Array = [];
	
	//===============================================================================================
	// 
	//===============================================================================================
	public function SaveLoadMenu(floorP:FloorPlan,showBuildDefa:Function=null):void
	{
		floorPlan = floorP;
				
		showBuildDefaultRoom = showBuildDefa;
		
		callBackFn = function(idx:int):void
		{
			if (idx==0)			// new document
				askToNew();
			else if (idx==1)	// save file
				askToSave();
			else				// load saved data
				askToLoad(idx-2);
		}//endfunction
		
		Btns = new Vector.<Sprite>();
		super(Btns,3,2,callBackFn);		// menu of 3 rows by 2 cols
		updateBtns();
		hasInit = true;
	}//endconstr
	
	//===============================================================================================
	// dialog to confirm new
	//===============================================================================================
	private function askToNew():void
	{
		var askNew:Sprite = new DialogMenu(FloorPlanner.Lang.SaveLoad.AskToNew.@txt,
									Vector.<String>([	FloorPlanner.Lang.SaveLoad.Confirm.@txt,
														FloorPlanner.Lang.SaveLoad.Cancel.@txt]),
									Vector.<Function>([function():void 
														{
															floorPlan.clearAll();
															overlay.parent.removeChild(overlay);
															if (showBuildDefaultRoom != null) showBuildDefaultRoom();
														},
														function():void 
														{
															overlay.parent.removeChild(overlay);
														}])); 
		askNew.x = (this.width-askNew.width)/2;
		askNew.y = (this.height-askNew.height)/2;
		overlay = new Sprite();
		overlay.graphics.beginFill(0xFFFFFF,0.5);
		overlay.graphics.drawRoundRect(0,0,this.width,this.height,20);
		overlay.graphics.endFill();
		overlay.addChild(askNew);
		addChild(overlay);
	}//endfunction
	
	//===============================================================================================
	// dialog to confirm save
	//===============================================================================================
	private function askToSave():void
	{
		var askSaveFile:Sprite = new DialogMenu(FloorPlanner.Lang.SaveLoad.AskToSave.@txt,
									Vector.<String>([	FloorPlanner.Lang.SaveLoad.Confirm.@txt,
														FloorPlanner.Lang.SaveLoad.Cancel.@txt]),
									Vector.<Function>([function():void 
														{
															saveToServer();
															overlay.parent.removeChild(overlay);
															updateBtns();
														},
														function():void 
														{
															overlay.parent.removeChild(overlay);
														}])); 
		askSaveFile.x = (this.width-askSaveFile.width)/2;
		askSaveFile.y = (this.height-askSaveFile.height)/2;
		overlay = new Sprite();
		overlay.graphics.beginFill(0xFFFFFF,0.5);
		overlay.graphics.drawRoundRect(0,0,this.width,this.height,20);
		overlay.graphics.endFill();
		overlay.addChild(askSaveFile);
		addChild(overlay);
	}//endfunction
	
	//===============================================================================================
	// dialog to load data
	//===============================================================================================
	private function askToLoad(idx:int):void
	{
		var askLoadFile:Sprite = new DialogMenu(FloorPlanner.Lang.SaveLoad.AskToLoad.@txt,
									Vector.<String>([	FloorPlanner.Lang.SaveLoad.Confirm.@txt,
														FloorPlanner.Lang.SaveLoad.Cancel.@txt,
														FloorPlanner.Lang.SaveLoad.DeleteEntry.@txt]),
									Vector.<Function>([function():void 
														{	// LOAD
															floorPlan.importData(saveData[idx].data);
															overlay.parent.removeChild(overlay);
														},
														function():void 
														{	// CANCEL
															overlay.parent.removeChild(overlay);
														},
														function():void 
														{	// DELETE
															deleteDataFromServer(saveData[idx].id);
															overlay.parent.removeChild(overlay);
															updateBtns();
														}])); 
		askLoadFile.x = (this.width-askLoadFile.width)/2;
		askLoadFile.y = (this.height-askLoadFile.height)/2;
		overlay = new Sprite();							// overlay to cover the entire menu 
		overlay.graphics.beginFill(0xFFFFFF,0.5);
		overlay.graphics.drawRoundRect(0,0,this.width,this.height,20);
		overlay.graphics.endFill();
		overlay.addChild(askLoadFile);
		addChild(overlay);
	}//endfunction
	
	//===============================================================================================
	// Refresh buttons after save operation etc
	//===============================================================================================
	private function updateBtns():void
	{
		// ----- try loading user save data 
		var ldr:URLLoader = new URLLoader(new URLRequest(FloorPlanner.apiUrl + "?n=api&a=scheme&c=house&m=index&token=" + FloorPlanner.userToken));
		function onComplete(ev:Event):void
		{
			var dat:Object = JSON.parse(ldr.data);
			trace("GOT SAVE LIST :  ldr.data : "+Utils.prnObject(dat));
			_updateBtns(dat.data);			
		}//endfunction
		ldr.addEventListener(Event.COMPLETE,onComplete);
	}//endfunction
	
	//===============================================================================================
	// Refresh buttons after save operation etc
	//===============================================================================================
	private function _updateBtns(saveObj:Object=null):void
	{
		
		Btns = new Vector.<Sprite>();
		var BtnBmds:Vector.<BitmapData> = new Vector.<BitmapData>();
		
		// --------------------------------------------------------------------
		function makeBtn(ico:DisplayObject,txt:String):void
		{
			var btn:Sprite = new Sprite();
			btn.graphics.beginFill(0xFFFFFF,1);
			btn.graphics.drawRoundRect(0,0,100,100,10);
			btn.graphics.endFill();
			ico.x = (btn.width-ico.width)/2;
			ico.y = (btn.height-ico.height)/2;
			btn.addChild(ico);
			var tf:TextField = new TextField();
			tf.autoSize = "left";
			tf.wordWrap = false;
			do {
				var tff:TextFormat = tf.defaultTextFormat;
				tff.color = 0x000000;
				tff.size = int(tff.size)-1;
				tf.defaultTextFormat = tff;
				tf.text = txt+"";
			}
			while (tf.width>btn.width);
			tf.y = btn.height;
			tf.x = (btn.width-tf.width)/2;
			btn.addChild(tf);
			Btns.push(btn);
		}
		
		var ico:DisplayObject = (DisplayObject)(new (Class(getDefinitionByName(FloorPlanner.Lang.SaveLoad.NewDocument.@ico)))());
		makeBtn(ico,FloorPlanner.Lang.SaveLoad.NewDocument.@txt);
		ico = (DisplayObject)(new (Class(getDefinitionByName(FloorPlanner.Lang.SaveLoad.NewSave.@ico)))());
		makeBtn(ico,FloorPlanner.Lang.SaveLoad.NewSave.@txt);
		
		// ----- parse to array and start making btns icons
		saveData = new Array();
		if (saveObj!=null)
			for (var i:* in saveObj)
			{
				saveData.push(saveObj[i]);
				var bmd:BitmapData = new BitmapData(90,90,false,0x999999);
				BtnBmds.push(bmd);
				makeBtn(new Bitmap(bmd),saveObj[i].name);
			}
		if (hasInit) refresh();
		
		var idx:int=0;
		function loadNext():void
		{
			trace("loadNext() idx="+idx);
			function imgLoaded(img:Bitmap):void
			{
				trace("loaded...");
				var bmd:BitmapData = BtnBmds[idx];
				bmd.draw(img,new Matrix(bmd.width/img.width,0,0,bmd.height/img.height));
				idx++;
				if (idx<saveData.length)
					loadNext();
				else if (hasInit) 	
					refresh();
			}//endfunction
			var picUrl:String = FloorPlanner.apiUrl+saveData[idx].image;
			if (picUrl.indexOf("http")==-1)	picUrl = "http://"+picUrl;
			Utils.loadAsset(picUrl,imgLoaded);
		}//endfunction
		if (saveData.length>idx)	loadNext();
		
	}//endfunction
	
	//===============================================================================================
	// write floorplan data to server
	//===============================================================================================
	public function saveToServer():void
	{
		var bnds:Rectangle = floorPlan.overlay.getBounds(floorPlan.overlay);
		var M:Array = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
		var dat:Date = new Date();
		
		// ----- sends data to server
		var ldr:URLLoader = new URLLoader();
		var req:URLRequest = new URLRequest(FloorPlanner.apiUrl + "?n=api&a=scheme&c=house&m=add&token=" + FloorPlanner.userToken);
		req.method = "post";  
		bnds = floorPlan.boundRect();
		var o:Object = {houseName:dat.date+" "+M[dat.month]+" "+dat.fullYear, 
						spacelength:bnds.width, 
						spacewidth:bnds.height, 
						spaceheight:floorPlan.ceilingHeight, 
						json:floorPlan.exportData(), 
						productjson:"", 
						desc:dat.date+" "+M[dat.month]+" "+dat.fullYear};
		req.data = JSON.stringify(o);
		function onComplete(ev:Event):void
		{
			trace("UPLOADED  ldr.data -> "+ldr.data);
			var o:Object = JSON.parse(ldr.data);
			//updateBtns();
			uploadWallPics(o.data.id);
		}//endfunction
		ldr.addEventListener(Event.COMPLETE, onComplete);
		ldr.load(req);
	}//endfunction
	
	//===============================================================================================
	// laod floorplan data of id from server
	//===============================================================================================
	public function loadDataFromServer(id:String):void
	{
		trace("loadDataFromServer("+id+")");
		var ldr:URLLoader = new URLLoader();
		var req:URLRequest = new URLRequest(FloorPlanner.apiUrl+"?n=api&a=scheme&c=house&m=info&token="+FloorPlanner.userToken+"&id="+id);
		function onComplete(ev:Event):void
		{
			trace("GOT DATA FROM SERVER  ldr.data : "+ldr.data);
			var o:Object = JSON.parse(ldr.data);
			//floorPlan.importData(o.data);	// imports the data string
		}//endfunction
		ldr.addEventListener(Event.COMPLETE, onComplete);
		ldr.load(req);
	}//endfunction
		
	//===============================================================================================
	// delete floorplan given id
	//===============================================================================================
	private function deleteDataFromServer(id:String):void
	{
		trace("deleteDataFromServer("+id+")");
		var ldr:URLLoader = new URLLoader();
		var req:URLRequest = new URLRequest(FloorPlanner.apiUrl+"?n=api&a=scheme&c=house&m=del&token"+FloorPlanner.userToken+"&id="+id);
		function onComplete(ev:Event):void
		{
			trace("Deleted DATA FROM SERVER  ldr.data : "+ldr.data);
		}//endfunction
		ldr.addEventListener(Event.COMPLETE, onComplete);
		ldr.load(req);
	}//endfunction
		
	//===============================================================================================
	// upload each wall pic to server
	//===============================================================================================
	private function uploadWallPics(saveId:String):void
	{
		var idx:int = 0;
		
		var overlay:Sprite = new Sprite();
		overlay.graphics.beginFill(0, 0.8);
		overlay.graphics.drawRect(0, 0, stage.stageWidth, stage.stageHeight);
		overlay.graphics.endFill();
		var tf:TextField = new TextField();
		var tff:TextFormat = tf.defaultTextFormat;
		tff.color = 0xFFFFFF;
		tff.size = 14;
		tff.bold = true;
		tf.defaultTextFormat = tff;
		tf.autoSize = "left";
		tf.wordWrap = false;
		overlay.addChild(tf);
		this.parent.addChild(overlay);
		
		function uploadFloorPic(callBack:Function=null):void
		{
			floorPlan.refresh();
			var b:Rectangle = floorPlan.overlay.getBounds(floorPlan.overlay);
			var bmd:BitmapData = new BitmapData(b.width*2+20, b.height*2+20, false, 0xFFFFFF);
			bmd.draw(floorPlan.overlay, new Matrix(2, 0, 0, 2, 10 - b.left*2, 10 - b.top*2));
			var bmp:Bitmap = new Bitmap(bmd);
			bmp.scaleX = bmp.scaleY = 1 / 10;
			bmp.x = (overlay.width - bmp.width) / 2;
			bmp.y = (overlay.height - bmp.height) / 2;
			while (overlay.numChildren > 1) overlay.removeChildAt(1);
			overlay.addChild(bmp);
			tf.text = "Uploading floorplan";
			tf.x = (overlay.width - tf.width) / 2;
			tf.y = bmp.y + bmp.height + 3;
			var jpgEnc:JPGEncoder = new JPGEncoder(80);
			var ba:ByteArray = jpgEnc.encode(bmd);
			var ldr:URLLoader = new URLLoader();
			var req:URLRequest = new URLRequest(FloorPlanner.apiUrl + "?n=api&a=scheme&c=scheme_house_pic&m=add&type=0&token=" + FloorPlanner.userToken+"&houseid="+saveId+"&name=floorplan");
			req.contentType = 'application/octet-stream';
			req.method = "post";  
			req.data = ba;
			function onComplete(ev:Event):void
			{
				trace("UPLOADED floor pic ldr.data : "+ldr.data);
				if (callBack!=null) callBack();
			}//endfunction
			ldr.addEventListener(Event.COMPLETE, onComplete);
			ldr.load(req);
		}//endfunction
		
		function uploadWallPics():void
		{
			if (idx >= floorPlan.Walls.length)
			{
				trace("upload wall pic done!");
				if (overlay.parent != null) overlay.parent.removeChild(overlay);
				updateBtns();
				return;
			}
			var wall:Wall = floorPlan.Walls[idx];
			wall.updateSideView();
			var b:Rectangle = wall.sideView.getBounds(wall.sideView);
			var bmd:BitmapData = new BitmapData(b.width+20, b.height+20, false, 0xFFFFFF);
			bmd.draw(wall.sideView, new Matrix(1, 0, 0, 1, 10 - b.left, 10 - b.top));
			var bmp:Bitmap = new Bitmap(bmd);
			bmp.x = (overlay.width - bmp.width) / 2;
			bmp.y = (overlay.height - bmp.height) / 2;
			while (overlay.numChildren > 1) overlay.removeChildAt(1);
			overlay.addChild(bmp);
			tf.text = "Uploading wall" + idx;
			tf.x = (overlay.width - tf.width) / 2;
			tf.y = bmp.y + bmp.height + 3;
			var jpgEnc:JPGEncoder = new JPGEncoder(80);
			var ba:ByteArray = jpgEnc.encode(bmd);
			var ldr:URLLoader = new URLLoader();
			var req:URLRequest = new URLRequest(FloorPlanner.apiUrl + "?n=api&a=scheme&c=scheme_house_pic&m=add&type=1&token=" + FloorPlanner.userToken+"&houseid="+saveId+"&name=wall"+idx);
			req.contentType = 'application/octet-stream';
			req.method = "post";  
			req.data = ba;
			function onComplete(ev:Event):void
			{
				//trace("UPLOADED wall"+idx+" pic ldr.data : "+ldr.data);
				idx++;
				uploadWallPics();
			}//endfunction
			ldr.addEventListener(Event.COMPLETE, onComplete);
			ldr.load(req);
		}//endfunction
		
		uploadFloorPic(uploadWallPics);
	}//endfunction
	
}//endclass

class ColorMenu extends IconsMenu
{
	public function ColorMenu(callBack:Function):void
	{
		var C:Array = [	0x000000,0xFFFFFF,0xFFFF00,0x00FFFF,0xFF00FF,0xFF0000,0x00FF00,0x0000FF,
						0x004F9C,0x103749,0x081732,0x51BCEC,0x006B67,0x006B67,0x650B25,0x4B1546,0x692C90,
						0x68BC43,0x008651,0x004732,0x41515C,0xADBBBB,0xADBBBB,0xEE2D23,0xF4C4DC,0xEC4598,
						0x8B5A42,0x8B5A42,0x948670,0x948670,0x948670];
		var Icos:Vector.<Sprite> = new Vector.<Sprite>();
		for (var i:int=C.length-1; i>-1; i--)
		{
			var ico:Sprite = new Sprite();
			ico.graphics.beginFill(C[i],1);
			ico.graphics.drawRoundRect(0,0,20,20,5);
			ico.graphics.endFill();
			Icos.unshift(ico);
		}
		super(Icos,5,5,function (idx:int):void {callBack(C[idx]);});
	}//endfunction
}//endclass

class WireGrid extends Sprite
{
	//=============================================================================================
	// constructor for background grid markings sprite
	//=============================================================================================
	public function WireGrid():void
	{
		var ppp:Sprite = this;
		function onResize(ev:Event):void
		{
			update();
		}
		function onAddedToStage(ev:Event):void
		{
			update();
			ppp.removeEventListener(Event.ADDED_TO_STAGE,onAddedToStage);
			stage.addEventListener(Event.RESIZE,onResize);
		}
		ppp.addEventListener(Event.ADDED_TO_STAGE,onAddedToStage);
	}//endfunction
	
	//=============================================================================================
	// 
	//=============================================================================================
	public function zoom(sc:Number):void
	{
		if (stage==null) return;
		var sw:int = stage.stageWidth;
		var sh:int = stage.stageHeight;
		
		// ----- shift so that zoom is in center
		var ompt:Point = new Point((-x+sw/2)/scaleX,(-y+sh/2)/scaleY);	// original middle point
		var nmpt:Point = new Point((-x+sw/2)/sc,(-y+sh/2)/sc);			// new skewed middle point
		var dv:Point = ompt.subtract(nmpt);
		x-= dv.x*sc;
		y-= dv.y*sc;
		
		scaleX = scaleY = sc;
		update();
	}//endfunction
	
	//=============================================================================================
	// redraws the grid background so the grid lines always cover the screen
	//=============================================================================================
	public function update():void
	{
		if (stage==null) return;
		var sw:int = stage.stageWidth;
		var sh:int = stage.stageHeight;
		
		var interval:int = 10;
		var rect:Rectangle = new Rectangle(-x/scaleX,-y/scaleY,sw/scaleX,sh/scaleY);	// define rectangle to draw
		
		// ----- draw bg color
		graphics.clear();
		graphics.beginFill(0xEEEEF3,1);
		graphics.drawRect(rect.x,rect.y,rect.width,rect.height);
		graphics.endFill();
		
		// ----- draw grid lines
		var i:int = 0;
		var a:int = int(rect.left/interval)*interval;
		for (i=a; i<=rect.right; i+=interval)	
		{
			if (i%(interval*10)==0)	graphics.lineStyle(0, 0xCCCCCC, 1);
			else					graphics.lineStyle(0, 0xE5E5E5, 1);
			graphics.moveTo(i,rect.top);
			graphics.lineTo(i,rect.bottom);
		}
		a = int(rect.top/interval)*interval;
		for (i=a; i<=rect.bottom; i+=interval)	
		{
			if (i%(interval*10)==0)	graphics.lineStyle(0, 0xCCCCCC, 1);
			else					graphics.lineStyle(0, 0xE5E5E5, 1);
			graphics.moveTo(rect.left,i);
			graphics.lineTo(rect.right,i);
		}
	}//endfunction
	
}//endclass

class FloorPlan
{
	public var Joints:Vector.<Point>;
	public var Walls:Vector.<Wall>;
	
	public var Lines:Vector.<Line>;
	public var LineEndings:Vector.<Point>;
	
	public var Furniture:Vector.<Item>;			// list of furniture items already on the stage
	public var floorAreas:Vector.<FloorArea>;	// list of floor area sprites already on the stage
	public var Labels:Vector.<TextField>;		// list of text labels added to drawing
	
	public var ceilingHeight:Number = 2;
	
	public var selected:* = null;				// of Furniture or Joint or Wall
	
	private var jointsOverlay:Sprite = null;	// to draw all the joint positions in
	public var overlay:Sprite = null;			// to add to display list
	public var FloorPatterns:Vector.<BitmapData> = null;
	
	//=============================================================================================
	//
	//=============================================================================================
	public function FloorPlan():void
	{
		Joints = new Vector.<Point>();
		Walls = new Vector.<Wall>();
		Lines = new Vector.<Line>();
		LineEndings = new Vector.<Point>();
		
		Furniture = new Vector.<Item>();
		floorAreas = new Vector.<FloorArea>();
		Labels = new Vector.<TextField>();
		
		jointsOverlay = new Sprite();
		overlay = new Sprite();
		overlay.buttonMode = true;
		
		FloorPatterns =  Vector.<BitmapData>([new Floor1(),
												new Floor2(),
												new Floor3(),
												new Floor4(),
												new Floor5(),
												new Floor6(),
												new Floor7(),
												new Floor8(),
												new Floor9(),
												new Floor10(),
												new Floor11(),
												new Floor12(),
												new Floor13()]);
	}//endfunction
	
	//=============================================================================================
	// removes everything and start from clean slate
	//=============================================================================================
	public function clearAll():void
	{
		selected = null;		// clear off selection
		
		if (furnitureCtrls!=null)
		{
			furnitureCtrls.parent.removeChild(furnitureCtrls);		// clear off furniture transform controls
			furnitureCtrls = null;
		}
		
		// ----- remove joints
		Joints = new Vector.<Point>();
		
		// ----- remove walls
		while (Walls.length>0)					// clear off prev walls
			overlay.removeChild(Walls.pop().planView);
				
		// ----- remove furniture
		while (Furniture.length>0)				// clear off prev furniture
		{
			overlay.removeChild(Furniture.pop().icon);
		}
		refresh();
	}//endfunction
	
	//=============================================================================================
	// covert data to JSON formatted string
	//=============================================================================================
	public function exportData(tmbData:String=null):String
	{
		var o:Object = new Object();
		o.Joints = Joints;
		o.Walls = Walls;
		o.Furniture = Furniture;
		o.Labels = Labels;
		o.floorAreas = floorAreas;
		if (tmbData!=null) o.tmb = tmbData;
		
		function replacer(k,v):*
		{
			if (v is Door)				// 
			{
				var o:Object = new Object();
				o.pivot = v.pivot;
				o.dir = v.dir;
				o.height = v.height;
				o.cls = getQualifiedClassName((Door)(v).icon);
				o.side = getQualifiedClassName((Door)(v).sideIcon);
				return o;
			}
			else if (v is Wall)			// joints become indexes
			{
				var wo:Object = new Object();
				wo.j1 = Joints.indexOf((Wall)(v).joint1);
				wo.j2 = Joints.indexOf((Wall)(v).joint2);
				wo.w = (Wall)(v).thickness;
				wo.Doors = (Wall)(v).Doors;
				return wo;
			}
			else if (v is FloorArea)	// floor type
			{
				var flo:Object = new Object();
				flo.flooring = (FloorArea)(v).flooring;
				return flo;
			}
			else if (v is Item)			// furniture icons properties
			{
				var fo:Object = new Object();
				fo.cls = getQualifiedClassName((Item)(v).icon);
				fo.color = (Item)(v).color;
				fo.x = (Item)(v).icon.x;
				fo.y = (Item)(v).icon.y;
				fo.rot = (Item)(v).icon.rotation;
				fo.width = (Item)(v).icon.width;
				fo.length = (Item)(v).icon.height;
				return fo;
			}
			else if(v is Point)			// so only x,y vals are converted
			{
				var po:Object = new Object();
				po.x = v.x;
				po.y = v.y;
				return po;
			}
			else if (v is TextField)
			{
				var to:Object = new Object();
				to.x = v.x;
				to.y = v.y;
				to.text = v.text;
				to.size = (TextField)(v).defaultTextFormat.size;
				to.color = (TextField)(v).defaultTextFormat.color;
				return to;
			}
			
			return v;
		}
		return JSON.stringify(o,replacer);
	}//endfunction
	
	//=============================================================================================
	//
	//=============================================================================================
	public function boundRect():Rectangle
	{
		var r:Rectangle = new Rectangle();
		for (var i:int=Joints.length-1; i>-1; i--)
		{
			var jt:Point = Joints[i];
			if (jt.x<r.left)	r.left = jt.x;
			if (jt.x>r.right)	r.right = jt.x;
			if (jt.y<r.top)		r.top = jt.y;
			if (jt.y>r.bottom)	r.bottom = jt.y;
		}
		return r;
	}//endfunction
	
	//=============================================================================================
	// converts from JSON data back to floorPlan, original data will be OVERRIDDEN
	//=============================================================================================
	public function importData(dat:String):void
	{
		selected = null;		// clear off selection
		
		if (furnitureCtrls!=null)
		{
			furnitureCtrls.parent.removeChild(furnitureCtrls);		// clear off furniture transform controls
			furnitureCtrls = null;
		}
		
		var o:Object = JSON.parse(dat);
		
		// ----- replace joints -------------------------------------
		Joints = new Vector.<Point>();
		if (o.Joints!=null)
		for (var i:int=o.Joints.length-1; i>-1; i--)
		{
			var po:Object = o.Joints[i];
			Joints.unshift(new Point(po.x,po.y));
		}
		
		// ----- replace walls --------------------------------------
		while (Walls.length>0)					// clear off prev walls
			overlay.removeChild(Walls.pop().planView);
		if (o.Walls!=null)
		for (i=o.Walls.length-1; i>-1; i--)		// add in new walls
		{
			var wo:Object = o.Walls[i];
			var wall:Wall = new Wall(Joints[wo.j1],Joints[wo.j2],wo.w,ceilingHeight);
			for (var j:int=wo.Doors.length-1; j>-1; j--)
			{
				var d:Object = wo.Doors[j];
				var doorIco:Sprite = new (Class(getDefinitionByName(d.cls)))() as Sprite;
				var doorSideIco:Sprite = null;
				if (d.side!=null && d.side!="null")	
					doorSideIco = new (Class(getDefinitionByName(d.side)))() as Sprite;
				else
				{
					try {
					doorSideIco = new (Class(getDefinitionByName(d.cls+"SV")))() as Sprite;
					} catch (e:Error) {trace("oopss no "+d.cls+"SV");}
				}
				trace("d.side="+d.side+"   doorSideIco="+doorSideIco);
				var door:Door = new Door(Number(d.pivot),Number(d.dir),doorIco,doorSideIco);
				if (d.height!=null && d.height!="null") 
					door.height = Number(d.height);
				else
					door.height=1;
				wall.addDoor(door);
			}
			overlay.addChild(wall.planView);
			Walls.unshift(wall);
		}
		
		// ----- replace furniture ----------------------------------
		while (Furniture.length>0)				// clear off prev furniture
		{
			var itm:Item = Furniture.pop();
			overlay.removeChild(itm.icon);
		}
		if (o.Furniture!=null)
		for (i=o.Furniture.length-1; i>-1; i--)		// add in new walls
		{
			var fo:Object = o.Furniture[i];
			var fur:Sprite = new (Class(getDefinitionByName(fo.cls)))() as Sprite;
			fur.filters = [new DropShadowFilter(1,90,0x000000,1,8,8,1)];
			if (fur is MovieClip) (MovieClip)(fur).gotoAndStop(fo.color);
			fur.x = fo.x;
			fur.y = fo.y;
			fur.rotation = fo.rot;
			if (fo.scX!=null)	fur.scaleX = fo.scX;
			if (fo.scY!=null)	fur.scaleY = fo.scY;
			if (fo.width!=null)	fur.width = fo.width;
			if (fo.length!=null)	fur.height = fo.length;
			itm = new Item(fur);
			Furniture.unshift(itm);
			overlay.addChild(fur);
		}
		
		// ----- replace text labels --------------------------------
		while (Labels.length>0)
			overlay.removeChild(Labels.pop());
		if (o.Labels!=null)
		for (i=o.Labels.length-1; i>-1; i--)		// add in new walls
		{
			var lo:Object = o.Labels[i];
			var tf:TextField = new TextField();
			tf.x = lo.x;
			tf.y = lo.y;
			tf.autoSize = "left";
			tf.wordWrap = false;
			tf.selectable = false;
			var tff:TextFormat = tf.defaultTextFormat;
			tff.size = Number(lo.size);
			tff.color = uint(lo.color);
			tf.defaultTextFormat = tff;
			tf.text = lo.text;
			Labels.push(tf);
			overlay.addChild(tf);
		}
		// ----- replace flooring -----------------------------------
		while (floorAreas.length>0)
			overlay.removeChild(floorAreas.pop().icon);
		if (o.floorAreas!=null)
		for (i=o.floorAreas.length-1; i>-1; i--)	// add in new flooring
		{
			var flo:Object = o.floorAreas[i];
			var fa:FloorArea = new FloorArea(flo.flooring);
			floorAreas.unshift(fa);		// order is important
			overlay.addChildAt(fa.icon,0);
		}
		
		refresh();
	}//endfunction
	
	//=============================================================================================
	// 
	//=============================================================================================
	public function createLabel(x:int,y:int):TextField
	{
		var base:Sprite = new Sprite();
		overlay.addChild(base);
		base.filters = [new DropShadowFilter(4,90,0x000000,1,4,4,0.5)];
		
		var tf:TextField = new TextField();
		tf.autoSize = "left";
		tf.wordWrap = false;
		var tff:TextFormat = tf.defaultTextFormat;
		tff.size = 20;
		tf.defaultTextFormat = tff;
		tf.type = "input";
		tf.background = true;
		overlay.stage.focus = tf;
		tf.x = x;
		tf.y = y;
		base.addChild(tf);
		overlay.addChild(base);
		
		var downPt:Point = null;
		function mouseDownHandler(ev:Event=null):void
		{
			downPt = new Point(overlay.mouseX,overlay.mouseY);
		}
		function changeHandler(ev:Event=null):void
		{
			base.graphics.clear();
			FloatingMenu.drawStripedRect(base,tf.x-10,tf.y-10,tf.width+20,tf.height+20,0xFFFFFF,0xF6F6F6,20,10);
		}
		function finalize(ev:Event=null):void
		{
			if (tf.hitTestPoint(overlay.stage.mouseX,overlay.stage.mouseY))
				return;
			if ((overlay.mouseX-downPt.x)*(overlay.mouseX-downPt.x)+(overlay.mouseY-downPt.y)*(overlay.mouseY-downPt.y)>1)
				return;
			tf.background = false;
			tf.htmlText = tf.text;
			tf.type = "dynamic";
			tf.selectable = false;
			overlay.removeChild(base);
			base.removeChild(tf);
			Labels.push(tf);
			overlay.addChild(tf);
			tf.removeEventListener(Event.ENTER_FRAME,changeHandler);
			overlay.stage.removeEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
			overlay.stage.removeEventListener(MouseEvent.CLICK,finalize);
		}
		tf.addEventListener(Event.ENTER_FRAME,changeHandler);
		overlay.stage.addEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
		overlay.stage.addEventListener(MouseEvent.CLICK,finalize);
		
		return tf;
	}//endfunction
	
	//=============================================================================================
	// 
	//=============================================================================================
	public function removeLabel(tf:TextField):void
	{
		if (Labels.indexOf(tf)!=-1)	Labels.splice(Labels.indexOf(tf),1);
		if (tf.parent!=null)	tf.parent.removeChild(tf);
	}//endfunction
	
	//=============================================================================================
	// creates and add wall to floorplan 
	//=============================================================================================
	public function createLine(pt1:Point, pt2:Point):Line
	{
		for (var i:int = LineEndings.length - 1; i > -1; i--)
		{
			if (LineEndings[i].subtract(pt1).length < 3)	pt1 = LineEndings[i];
		}
		
		var line:Line = new Line(pt1, pt2);
		Lines.push(line);
		if (LineEndings.indexOf(line.joint1)==-1) LineEndings.push(line.joint1);
		if (LineEndings.indexOf(line.joint2)==-1) LineEndings.push(line.joint2);
		line.refresh();
		overlay.addChild(line.planView);
		return line;
	}//endfunction
	
	//=============================================================================================
	// cleanly remove wall and its unused joints
	//=============================================================================================
	public function removeLine(line:Line):void
	{
		if (Lines.indexOf(line) != -1)	Lines.splice(Lines.indexOf(line), 1);
		if (line.planView.parent != null)	line.planView.parent.removeChild(line.planView);
		
		var canRemJt1:Boolean = true;
		var canRemJt2:Boolean = true;
		for (var i:int=Lines.length-1; i>-1; i--)
		{
			var l:Line = Lines[i];
			if (l.joint1==line.joint1 || l.joint2==line.joint1)	canRemJt1 = false;
			if (l.joint1==line.joint2 || l.joint2==line.joint2)	canRemJt2 = false;
		}
		if (canRemJt1 && LineEndings.indexOf(line.joint1)!=-1) LineEndings.splice(LineEndings.indexOf(line.joint1),1);
		if (canRemJt2 && LineEndings.indexOf(line.joint2)!=-1) LineEndings.splice(LineEndings.indexOf(line.joint2),1);
	}//endfunction
	
	//=============================================================================================
	// creates and add wall to floorplan 
	//=============================================================================================
	public function createWall(pt1:Point, pt2:Point, width:Number=10, snapDist:Number=10):Wall
	{
		function registerWall(wall:Wall):Wall
		{
			Walls.push(wall);
			drawWall(wall);
			overlay.addChild(wall.planView);
			return wall;
		}
	
		// ----- snap pt1 to existing joint if near
		var nearest:Point = nearestJoint(pt1,snapDist);
		if (nearest!=null)	
			pt1 = nearest;
		else
		{	// snap starting point to nearest wall if approprate
			var snapW:Wall = nearestNonAdjWall(pt1, snapDist);
			if (snapW!=null)	
			{
				pt1 = projectedWallPosition(snapW, pt1);
				removeWall(snapW);
				registerWall(new Wall(snapW.joint1, pt1,snapW.thickness,ceilingHeight));
				registerWall(new Wall(snapW.joint2, pt1,snapW.thickness,ceilingHeight));
			}
			Joints.push(pt1);
		}
		
		// ----- snap pt2 to existing joint not pt1
		nearest = null;
		for (var i:int=Joints.length-1; i>-1; i--)
			if (Joints[i]!=pt1)
			{
				if (nearest==null || Joints[i].subtract(pt2).length<nearest.subtract(pt2).length)
					nearest=Joints[i];
			}
		if (nearest!=null && nearest.subtract(pt2).length<snapDist)	
			pt2 = nearest;
		else
			Joints.push(pt2);
		
		// ----- register new wall
		return registerWall(new Wall(pt1, pt2, width,ceilingHeight));
	}//endfunction
	
	//=============================================================================================
	// cleanly remove wall and its unused joints
	//=============================================================================================
	public function removeWall(wall:Wall):void
	{
		if (Walls.indexOf(wall)!=-1)	Walls.splice(Walls.indexOf(wall),1);
		if (wall.planView.parent!=null)	wall.planView.parent.removeChild(wall.planView);	
		
		var canRemJt1:Boolean = true;
		var canRemJt2:Boolean = true;
		for (var i:int=Walls.length-1; i>-1; i--)
		{
			var w:Wall = Walls[i];
			if (w.joint1==wall.joint1 || w.joint2==wall.joint1)	canRemJt1 = false;
			if (w.joint1==wall.joint2 || w.joint2==wall.joint2)	canRemJt2 = false;
		}
		if (canRemJt1 && Joints.indexOf(wall.joint1)!=-1) Joints.splice(Joints.indexOf(wall.joint1),1);
		if (canRemJt2 && Joints.indexOf(wall.joint2)!=-1) Joints.splice(Joints.indexOf(wall.joint2),1);
	}//endfunction
	
	//=============================================================================================
	// finds the nearest joint to this position
	//=============================================================================================
	public function nearestJoint(posn:Point,cutOff:Number):Point
	{
		var joint:Point = null;
		for (var i:int=Joints.length-1; i>-1; i--)
			if (Joints[i]!=posn && cutOff>Joints[i].subtract(posn).length)
			{
				joint = Joints[i];
				cutOff = joint.subtract(posn).length;
			}
		return joint;
	}//endfunction
	
	//=============================================================================================
	// finds the nearest line end to this position
	//=============================================================================================
	public function nearestLineEnd(posn:Point,cutOff:Number):Point
	{
		var pt:Point = null;
		for (var i:int=LineEndings.length-1; i>-1; i--)
			if (LineEndings[i]!=pt && cutOff>LineEndings[i].subtract(posn).length)
			{
				pt = LineEndings[i];
				cutOff = pt.subtract(posn).length;
			}
		//trace("nearestLineEnd("+posn+","+cutOff+") -> "+pt);
		return pt;
	}//endfunction
	
	//=============================================================================================
	// replace joint with given new joint, used for snapping together wall joints
	//=============================================================================================
	public function replaceJointWith(jt:Point,njt:Point):void
	{
		// ----- register joints
		if (Joints.indexOf(njt)!=-1)	// njt already exists
		{	// remove jt
			if (Joints.indexOf(jt)!=-1)	Joints.splice(Joints.indexOf(jt),1);
		}
		else
		{	// else replace with njt
			if (Joints.indexOf(jt)==-1)	Joints.push(njt);
			else						Joints[Joints.indexOf(jt)]=njt;
		}
		
		// ----- replace with new joint
		for (var i:int=Walls.length-1; i>-1; i--)
		{
			var wall:Wall = Walls[i];
			if (wall.joint1==jt)	wall.joint1=njt;
			if (wall.joint2==jt)	wall.joint2=njt;
		}
		
		// ----- remove 0 length and duplicates
		for (i=Walls.length-1; i>-1; i--)
		{
			wall = Walls[i];
			if (wall.joint1==wall.joint2)
			{	// remove any 0 length wall
				removeWall(wall);
			}
			else
			{	// remove duplicate wall
				for (var j:int=i-1; j>-1; j--)
					if ((Walls[j].joint1==wall.joint1 && Walls[j].joint2==wall.joint2) || 
						(Walls[j].joint1==wall.joint2 && Walls[j].joint2==wall.joint1))
					{
						removeWall(wall);
					}
			}
		}
	}//endfunction
	
	//=============================================================================================
	// finds the nearest wall to this position, where posn cannot be joint1 or joint2
	//=============================================================================================
	public function nearestNonAdjWall(posn:Point,cutOff:Number):Wall
	{
		var wall:Wall = null;
		for (var i:int=Walls.length-1; i>-1; i--)
		{
			var w:Wall = Walls[i];
			if (w.joint1!=posn && w.joint2!=posn && cutOff>w.perpenticularDist(posn))
			{
				wall = w;
				cutOff = wall.perpenticularDist(posn);
			}
		}
		return wall;
	}//endfunction
	
	//=============================================================================================
	// returns wall that collided with given wall or null 
	//=============================================================================================
	public function chkWallCollide(wall:Wall):Wall
	{
		for (var i:int=Walls.length-1; i>-1; i--)
		{
			var w:Wall = Walls[i];
			if (segmentsIntersectPt(w.joint1.x,w.joint1.y,w.joint2.x,w.joint2.y, wall.joint1.x,wall.joint1.y,wall.joint2.x,wall.joint2.y)!=null)
				return w;
		}
		
		return null;
	}//endfunction
	
	//=============================================================================================
	// find position of point projected onto wall
	//=============================================================================================
	public function projectedWallPosition(wall:Wall, pt:Point) : Point
	{
		var vpt:Point = pt.subtract(wall.joint1);
		var dir:Point = wall.joint2.subtract(wall.joint1);
		dir.normalize(1);
		var k:Number =dir.x*vpt.x + dir.y*vpt.y;
		
		return new Point(wall.joint1.x + dir.x*k, wall.joint1.y + dir.y * k);;
	}//endfunction
	
	//=============================================================================================
	// redraws every wall
	//=============================================================================================
	public function refresh():void
	{
		// ----- redraw all walls ---------------------------------------------
		var i:int=0;
		for (i=Walls.length-1; i>-1; i--)
			drawWall(Walls[i]);
		
		// ----- redraw all lines ---------------------------------------------
		for (i=Lines.length-1; i>-1; i--)
			Lines[i].refresh();
		
		// ----- redraw enclosed floor areas ----------------------------------
		var A:Vector.<Vector.<Point>> = findIsolatedAreas();
		while (floorAreas.length<A.length) 
		{
			var fa:FloorArea = new FloorArea(floorAreas.length%FloorPatterns.length);
			floorAreas.push(fa);
			overlay.addChildAt(fa.icon,0);
		}
		while (floorAreas.length>A.length)
			overlay.removeChild(floorAreas.pop().icon);
		for (i=A.length-1; i>-1; i--)	// draw for each floorArea
			drawFloorArea(A[i],floorAreas[i]);
		
		// ----- redraw wall joint positions ----------------------------------
		jointsOverlay.graphics.clear();
		jointsOverlay.graphics.lineStyle(2,0x666666,1);
		for (i=Joints.length-1; i>-1; i--)
		{
			if (selected==Joints[i])
				jointsOverlay.graphics.beginFill(0xFF6600,1);
			else
				jointsOverlay.graphics.beginFill(0xE9E9E9,1);
			jointsOverlay.graphics.drawCircle(Joints[i].x,Joints[i].y,3);
			jointsOverlay.graphics.endFill();
		}
		if (jointsOverlay.parent!=null)
			jointsOverlay.parent.removeChild(jointsOverlay);
		overlay.addChild(jointsOverlay);
	}//endfunction
	
	//=============================================================================================
	// draws wall with any door and windows on it
	//=============================================================================================
	public function drawWall(wall:Wall):void
	{
		// ----- draw wall bounds
		var wallB:Vector.<Point> = wall.wallBounds(false);
				
		var ipt:Point = null;
		var j:int=0;
		var wb:Vector.<Point>=null;
		var Adj:Vector.<Wall> = connectedToJoint(wall.joint2);
		for (j=Adj.length-1; j>-1; j--)
		{
			wb = null;
			if (Adj[j].joint2==wall.joint2)		wb = Adj[j].wallBounds(true);	// ensure point ordering is correct
			else								wb = Adj[j].wallBounds(false);
			
			ipt = extendedSegsIntersectPt(wallB[0].x,wallB[0].y,wallB[1].x,wallB[1].y,wb[0].x,wb[0].y,wb[1].x,wb[1].y);
			if (ipt!=null)	wallB[1] = ipt;
			ipt = extendedSegsIntersectPt(wallB[3].x,wallB[3].y,wallB[2].x,wallB[2].y,wb[3].x,wb[3].y,wb[2].x,wb[2].y);
			if (ipt!=null)	wallB[2] = ipt;
		}
		
		Adj = connectedToJoint(wall.joint1);
		for (j=Adj.length-1; j>-1; j--)
		{
			wb = null;
			if (Adj[j].joint2==wall.joint1)		wb = Adj[j].wallBounds(false);	// ensure point ordering is correct
			else								wb = Adj[j].wallBounds(true);
			
			ipt = extendedSegsIntersectPt(wallB[0].x,wallB[0].y,wallB[1].x,wallB[1].y,wb[0].x,wb[0].y,wb[1].x,wb[1].y);
			if (ipt!=null)	wallB[0] = ipt;
			ipt = extendedSegsIntersectPt(wallB[3].x,wallB[3].y,wallB[2].x,wallB[2].y,wb[3].x,wb[3].y,wb[2].x,wb[2].y);
			if (ipt!=null)	wallB[3] = ipt;
		}
		// ----- draws the calculated wallB
		wall.planView.graphics.clear();
		while (wall.planView.numChildren>0)	wall.planView.removeChildAt(0);
		if (selected==wall)		wall.planView.graphics.beginFill(0xFF6600,1);
		else					wall.planView.graphics.beginFill(0x000000,1);
		wall.planView.graphics.moveTo(wallB[0].x,wallB[0].y);
		wall.planView.graphics.lineTo(wallB[1].x,wallB[1].y);
		wall.planView.graphics.lineTo(wallB[2].x,wallB[2].y);
		wall.planView.graphics.lineTo(wallB[3].x,wallB[3].y);
		wall.planView.graphics.lineTo(wallB[0].x,wallB[0].y);
		wall.planView.graphics.endFill();
		
		// ----- draw wall length info
		var ux:Number = wallB[1].x-wallB[0].x;
		var uy:Number = wallB[1].y-wallB[0].y;
		var vl:Number = Math.sqrt(ux*ux+uy*uy);
		ux/=vl; uy/=vl;
		drawI(wall.planView,wallB[0].x+uy*5,wallB[0].y-ux*5,wallB[1].x+uy*5,wallB[1].y-ux*5,10,true);
		drawI(wall.planView,wallB[2].x-uy*5,wallB[2].y+ux*5,wallB[3].x-uy*5,wallB[3].y+ux*5,10,true);
		
		// ----- draw all doors
		for (j=wall.Doors.length-1; j>-1; j--)
		{
			var door:Door = wall.Doors[j];
			var piv:Point = new Point(	wall.joint1.x + (wall.joint2.x-wall.joint1.x)*door.pivot,
										wall.joint1.y + (wall.joint2.y-wall.joint1.y)*door.pivot);
			var dir:Point = new Point(	(wall.joint2.x-wall.joint1.x)*door.dir,
										(wall.joint2.y-wall.joint1.y)*door.dir);
			var bearing:Number = Math.atan2(dir.x,-dir.y);
			if (selected==door)	
				drawBar(wall.planView,piv,piv.add(dir),wall.thickness,0xFF6600);	
			else
				drawBar(wall.planView,piv,piv.add(dir),wall.thickness,0xEEEEEE);
			door.icon.x = piv.x+dir.x/2;
			door.icon.y = piv.y+dir.y/2;
			door.icon.rotation = 0;
			door.icon.width = dir.length;
			door.icon.scaleY = door.icon.scaleX;
			door.icon.rotation = bearing*180/Math.PI+90;
			wall.planView.addChild(door.icon);
			/*
			var angL:Number = bearing+door.angL;
			var angR:Number = bearing+door.angR;
			wall.graphics.lineStyle(0,0x000000,1);
			var cnt:int = 0;
			wall.graphics.moveTo(piv.x,piv.y);
			for (var deg:Number=angL; deg<angR; deg+=Math.PI/32)	// draw the arc
			{
				if (cnt%2==0)
					wall.graphics.lineTo(piv.x+Math.sin(deg)*dir.length,piv.y-Math.cos(deg)*dir.length);
				else
					wall.graphics.moveTo(piv.x+Math.sin(deg)*dir.length,piv.y-Math.cos(deg)*dir.length);
				cnt++;
			}
			drawBar(wall,piv,piv.add(new Point(Math.sin(angL)*dir.length,-Math.cos(angL)*dir.length)),door.thickness);
			drawBar(wall,piv,piv.add(new Point(Math.sin(angR)*dir.length,-Math.cos(angR)*dir.length)),door.thickness);
			*/
		}
	}//endfunction
	
	//=============================================================================================
	// 
	//=============================================================================================
	public function addItem(itm:Item):void
	{
		trace("addItem("+itm+")");
		Furniture.push(itm);
		itm.icon.filters = [new DropShadowFilter(1,90,0x000000,1,8,8,1)];
		overlay.addChild(itm.icon);
		
		// ----- hack to start dragging
		if (overlay.stage!=null)
		{
			function enterFrameHandler(ev:Event=null) :void
			{
				itm.icon.x = overlay.mouseX;
				itm.icon.y = overlay.mouseY;
			}
			function mouseDownHandler(ev:Event=null):void
			{
				itm.icon.removeEventListener(Event.ENTER_FRAME,enterFrameHandler);
				overlay.stage.removeEventListener(MouseEvent.MOUSE_UP,mouseDownHandler);	
			}
			itm.icon.addEventListener(Event.ENTER_FRAME,enterFrameHandler);
			overlay.stage.addEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
		}
	}//endfunction
	
	//=============================================================================================
	// adds a furniture icon to floorplan
	//=============================================================================================
	public function addFurniture(fu:Sprite):void
	{
		fu.filters = [new DropShadowFilter(1,90,0x000000,1,8,8,1)];
		if (fu is MovieClip)
			Furniture.push(new Item(fu,(MovieClip)(fu).currentFrame));
		else
			Furniture.push(new Item(fu));
		
		overlay.addChild(fu);
		
		// ----- hack to start dragging
		if (overlay.stage!=null)
		{
			function enterFrameHandler(ev:Event=null) :void
			{
				fu.x = overlay.mouseX;
				fu.y = overlay.mouseY;
			}
			function mouseDownHandler(ev:Event=null):void
			{
				fu.removeEventListener(Event.ENTER_FRAME,enterFrameHandler);
				overlay.stage.removeEventListener(MouseEvent.MOUSE_UP,mouseDownHandler);	
			}
			fu.addEventListener(Event.ENTER_FRAME,enterFrameHandler);
			overlay.stage.addEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
		}
	}//endfunction
	
	//=============================================================================================
	// adds a furniture icon to floorplan
	//=============================================================================================
	public function removeFurniture(itm:Item):void
	{
		if (furnitureCtrls!=null)
		{
			furnitureCtrls.parent.removeChild(furnitureCtrls);		// clear off furniture transform controls
			furnitureCtrls = null;
		}
		if (Furniture.indexOf(itm)!=-1)	Furniture.splice(Furniture.indexOf(itm),1);
		if (itm.icon.parent!=null)			itm.icon.parent.removeChild(itm.icon);
	}//endfunction
	
	//=============================================================================================
	// selects and returns the Joint/Wall/Furniture selected under current mouse position, or null
	//=============================================================================================
	private var furnitureCtrls:Sprite = null;
	public function mouseSelect():*
	{
		var i:int=0;
		if (furnitureCtrls!=null)
		{
			if (furnitureCtrls.hitTestPoint(overlay.stage.mouseX,overlay.stage.mouseY)) 
				return selected;
			furnitureCtrls.parent.removeChild(furnitureCtrls);		// clear off furniture transform controls
			furnitureCtrls = null;
		}
		
		selected = null;	// clear prev selected
		
		// ----- chk if textfield selected ------------------------------------
		for (i=Labels.length-1; i>-1; i--)
			if (Labels[i].hitTestPoint(overlay.stage.mouseX,overlay.stage.mouseY))	
				selected = Labels[i];
		// ----- chk if furniture selected ------------------------------------
		if (selected==null)
		{
			for (i=Furniture.length-1; i>-1; i--)
				if (Furniture[i].icon.hitTestPoint(overlay.stage.mouseX,overlay.stage.mouseY))	// 
					selected = Furniture[i];
		
			if (selected!=null)
			{
				furnitureCtrls = furnitureTransformControls(selected.icon);
				overlay.addChild(furnitureCtrls);
			}
		}
		// ----- chk if near any line end -------------------------------------
		if (selected==null)
			selected = nearestLineEnd(new Point(overlay.mouseX,overlay.mouseY), 10);
		// ----- chk if near any joint ----------------------------------------
		if (selected==null)
			selected = nearestJoint(new Point(overlay.mouseX,overlay.mouseY), 10);
		// ----- chk if line selected -----------------------------------------
		if (selected==null)
			for (i=Lines.length-1; i>-1; i--)
				if (Lines[i].planView.hitTestPoint(overlay.stage.mouseX,overlay.stage.mouseY))	
					selected = Lines[i];
		// ----- chk if near any wall -----------------------------------------
		if (selected==null)
		{
			selected = nearestNonAdjWall(new Point(overlay.mouseX,overlay.mouseY), 10);		
			if (selected!=null)
			{
				var wall:Wall = selected as Wall;
				for (i=wall.Doors.length-1; i>-1; i--)
					if (wall.Doors[i].icon.hitTestPoint(overlay.stage.mouseX,overlay.stage.mouseY))
						selected = wall.Doors[i];
			}
		}
		// ----- chk if floor area selected -----------------------------------
		if (selected==null)
		{
			for (i=floorAreas.length-1; i>-1; i--)
				if (floorAreas[i].icon.hitTestPoint(overlay.stage.mouseX,overlay.stage.mouseY) &&
					floorAreas[i].icon.hitTestPoint(overlay.stage.mouseX,overlay.stage.mouseY,true))	// 
					selected = floorAreas[i];
		}
	}//endfunction
		
	//=============================================================================================
	// add controls to target furniture to shift scale rotate furniture
	//=============================================================================================
	public function furnitureTransformControls(targ:Sprite,marg:int=5,canRotate:Boolean=true):Sprite
	{
		var ctrls:Sprite = new Sprite();
		
		// --------------------------------------------------------------------
		function drawCtrls():void
		{
			var rot:Number = targ.rotation;
			var bnds:Rectangle = targ.getBounds(targ);
			bnds.x *= targ.scaleX;
			bnds.width *= targ.scaleX;
			bnds.y *= targ.scaleY;
			bnds.height *= targ.scaleY;
			while (ctrls.numChildren>0)	ctrls.removeChildAt(0);
			ctrls.graphics.clear();
			drawI(ctrls,bnds.left-marg,bnds.top,bnds.left-marg,bnds.bottom,marg*2,true);
			drawI(ctrls,bnds.left,bnds.top-marg,bnds.right,bnds.top-marg,marg*2,true);
			drawI(ctrls,bnds.right+marg,bnds.top,bnds.right+marg,bnds.bottom,marg*2);
			drawI(ctrls,bnds.left,bnds.bottom+marg,bnds.right,bnds.bottom+marg,marg*2);
			drawI(ctrls,bnds.left,bnds.top,bnds.right,bnds.bottom,marg*2,true);
			if (canRotate)
			{
				ctrls.graphics.beginFill(0x000000,1);
				ctrls.graphics.drawCircle(bnds.left-marg,bnds.top-marg,marg-1);
				ctrls.graphics.drawCircle(bnds.right+marg,bnds.bottom+marg,marg-1);
				ctrls.graphics.endFill();
			}
			ctrls.x = targ.x;
			ctrls.y = targ.y;
			ctrls.rotation = targ.rotation;
			ctrls.buttonMode = true;
		}
		drawCtrls();
		
		// --------------------------------------------------------------------
		var mouseDownPt:Point=null;
		var mode:String = "";
		var oPosn:Vector3D = null;	// {x,y,0,rotation}
		var oScale:Point = null;
		function enterFrameHandler(ev:Event) : void
		{
			if (mode=="drag")
			{
				targ.x = oPosn.x+ctrls.parent.mouseX-mouseDownPt.x;
				targ.y = oPosn.y+ctrls.parent.mouseY-mouseDownPt.y;
			}
			else if (mode=="rotate")
			{
				var pvx:Number = mouseDownPt.x-oPosn.x;
				var pvy:Number = mouseDownPt.y-oPosn.y;
				var pvl:Number = Math.sqrt(pvx*pvx+pvy*pvy);
				pvx/=pvl; pvy/=pvl;
				
				var qvx:Number = ctrls.parent.mouseX-oPosn.x;
				var qvy:Number = ctrls.parent.mouseY-oPosn.y;
				var qvl:Number = Math.sqrt(qvx*qvx+qvy*qvy);
				qvx/=qvl; qvy/=qvl;
				var angDiff:Number = Math.acos(pvx*qvx+pvy*qvy);
				if (pvx*qvy-pvy*qvx<0)	angDiff*=-1;
				targ.rotation = oPosn.w+angDiff/Math.PI*180;
				
				// ----- scale as you rotate
				var cd:Number = Math.sqrt((ctrls.parent.mouseX-targ.x)*(ctrls.parent.mouseX-targ.x) + (ctrls.parent.mouseY-targ.y)*(ctrls.parent.mouseY-targ.y));
				var od:Number = Math.sqrt((mouseDownPt.x-targ.x)*(mouseDownPt.x-targ.x) + (mouseDownPt.y-targ.y)*(mouseDownPt.y-targ.y));
				var sc:Number = cd/od;
				targ.scaleX = oScale.x*sc;
				targ.scaleY = oScale.y*sc;
				drawCtrls();
			}
			else if (mode=="scaleX" || mode=="scaleY")
			{
				var opt:Point = mouseDownPt.subtract(new Point(ctrls.x,ctrls.y));
				var mpt:Point = new Point(ctrls.parent.mouseX-ctrls.x,ctrls.parent.mouseY-ctrls.y);
				sc = mpt.length/opt.length;
				if (mode=="scaleX")	targ.scaleX = oScale.x*sc;
				if (mode=="scaleY")	targ.scaleY = oScale.y*sc;
				drawCtrls();
			}
					
			ctrls.rotation = targ.rotation;
			ctrls.x = targ.x;
			ctrls.y = targ.y;
		}//endfunction
		
		// --------------------------------------------------------------------
		function mouseDownHandler(ev:Event):void
		{
			mouseDownPt = new Point(ctrls.parent.mouseX,ctrls.parent.mouseY);	// parent coords
			oPosn = new Vector3D(targ.x,targ.y,0,targ.rotation);	// present position
			oScale = new Point(targ.scaleX,targ.scaleY);			// present scale 
			var bnds:Rectangle = targ.getBounds(targ);
			bnds.x *= targ.scaleX;
			bnds.width *= targ.scaleX;
			bnds.y *= targ.scaleY;
			bnds.height *= targ.scaleY;
			if (ctrls.mouseX>bnds.left && ctrls.mouseX<bnds.right &&
				ctrls.mouseY>bnds.top && ctrls.mouseY<bnds.bottom)
				mode = "drag";
			else if (ctrls.mouseX>bnds.left && ctrls.mouseX<bnds.right)
				mode = "scaleY";
			else if (ctrls.mouseY>bnds.top && ctrls.mouseY<bnds.bottom)
				mode = "scaleX";
			else if (canRotate)
				mode = "rotate";
		}//endfunction
		
		// --------------------------------------------------------------------
		function mouseUpHandler(ev:Event):void
		{
			mode = "";
		}//endfunction
		
		// --------------------------------------------------------------------
		function removeHandler(ev:Event):void
		{
			ctrls.removeEventListener(Event.REMOVED_FROM_STAGE,removeHandler);
			ctrls.removeEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
			ctrls.removeEventListener(Event.ENTER_FRAME,enterFrameHandler);
			overlay.stage.removeEventListener(MouseEvent.MOUSE_UP,mouseUpHandler);
		}
		
		ctrls.addEventListener(Event.REMOVED_FROM_STAGE,removeHandler);
		ctrls.addEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
		ctrls.addEventListener(Event.ENTER_FRAME,enterFrameHandler);
		overlay.stage.addEventListener(MouseEvent.MOUSE_UP,mouseUpHandler);
		
		return ctrls;
	}

	//=============================================================================================
	// convenience function to draw the length markings
	//=============================================================================================
	public static function drawI(s:Sprite,ax:Number,ay:Number,bx:Number,by:Number,w:int=6,showLen:Boolean=false):void
	{
		var vx:Number = bx-ax;
		var vy:Number = by-ay;
		var vl:Number = Math.sqrt(vx*vx+vy*vy);
		var ux:Number = vx/vl;
		var uy:Number = vy/vl;
		w/=2;
		// ----- draw rect
		s.graphics.lineStyle();
		s.graphics.beginFill(0x000000,0);
		s.graphics.moveTo(ax-uy*w,ay+ux*w);
		s.graphics.lineTo(ax+uy*w,ay-ux*w);
		s.graphics.lineTo(bx+uy*w,by-ux*w);	
		s.graphics.lineTo(bx-uy*w,by+ux*w);
		s.graphics.endFill();
		
		// ----- draw lines
		s.graphics.lineStyle(0,0x000000,1);
		s.graphics.moveTo(ax-uy*w,ay+ux*w);
		s.graphics.lineTo(ax+uy*w,ay-ux*w);
		s.graphics.moveTo(bx-uy*w,by+ux*w);
		s.graphics.lineTo(bx+uy*w,by-ux*w);	
		
		if (showLen)
		{
			var tf:TextField = new TextField();
			var tff:TextFormat = tf.defaultTextFormat;
			tff.size = 22;
			tff.color = 0x000000;
			tff.font = "arial";
			tf.defaultTextFormat = tff;
			tf.wordWrap = false;
			tf.autoSize = "left";
			tf.selectable = false;
			tf.text = (int(vl)/100)+"m";
			tf.filters = [new GlowFilter(0xFFFFFF,1,2,2,10)];
			var bmp:Bitmap = new Bitmap(new BitmapData(tf.width,tf.height,true,0x00000000),"auto",true);
			bmp.bitmapData.draw(tf,null,null,null,null,true);
			bmp.scaleX = bmp.scaleY = 0.5;
			var rot:Number = Math.atan2(ux,-uy)-Math.PI/2;
			var tx:Number = -0.5*bmp.width;
			var ty:Number = 0.5*bmp.height;
			bmp.x = tx*Math.cos(rot)+ty*Math.sin(rot);
			bmp.y = -(ty*Math.cos(rot)-tx*Math.sin(rot));
			bmp.rotation = rot/Math.PI*180;
			bmp.x += (ax+bx)/2;
			bmp.y += (ay + by) / 2;
			
			s.addChild(bmp);
			var tw:int = Math.max(bmp.width,bmp.height);
			s.graphics.moveTo(ax,ay);
			s.graphics.lineTo(ax+ux*(vl-tw)/2,ay+uy*(vl-tw)/2);
			s.graphics.moveTo(bx,by);
			s.graphics.lineTo(bx-ux*(vl-tw)/2,by-uy*(vl-tw)/2);
		}
		else
		{
			s.graphics.moveTo(ax,ay);
			s.graphics.lineTo(bx,by);
		}
	}//endfunction
	
	//=============================================================================================
	// convenience function to extend wall ends so they intersect nicely at acute angles
	//=============================================================================================
	private function extendedSegsIntersectPt(ax:Number,ay:Number,bx:Number,by:Number,cx:Number,cy:Number,dx:Number,dy:Number,ext:Number=100):Point
	{
		var pvx:Number = bx-ax;
		var pvy:Number = by-ay;
		var pvl:Number = Math.sqrt(pvx*pvx+pvy*pvy);
		pvx*=ext/pvl; pvy*=ext/pvl;
		var qvx:Number = dx-cx;
		var qvy:Number = dy-cy;
		var qvl:Number = Math.sqrt(qvx*qvx+qvy*qvy);
		qvx*=ext/qvl; qvy*=ext/qvl;
		return segmentsIntersectPt(ax-pvx,ay-pvy,bx+pvx,by+pvy,cx-qvx,cy-qvy,dx+qvx,dy+qvy);
	}//endfunction
	
	//=============================================================================================
	// draws a generic rectangle in given sprite s
	//=============================================================================================
	private function drawBar(s:Sprite,from:Point,to:Point,thickness:Number,color:uint=0xCCCCCC):void
	{
		var dir:Point = to.subtract(from);
		var dv:Point = new Point(dir.x/dir.length*thickness/2,dir.y/dir.length*thickness/2);
		s.graphics.beginFill(color,1);
		s.graphics.moveTo(from.x-dv.y,from.y+dv.x);
		s.graphics.lineTo(from.x+dv.y,from.y-dv.x);
		s.graphics.lineTo(to.x+dv.y,to.y-dv.x);
		s.graphics.lineTo(to.x-dv.y,to.y+dv.x);
		s.graphics.endFill();
	}//endfunction
	
	//=============================================================================================
	// finds all walls connected to given wall joint
	//=============================================================================================
	private function connectedToJoint(pt:Point):Vector.<Wall>
	{
		var W:Vector.<Wall> = new Vector.<Wall>();
		for (var i:int=Walls.length-1; i>-1; i--)
			if (Walls[i].joint1==pt || Walls[i].joint2==pt)
				W.unshift(Walls[i]);
		return W;
	}//endfunction
	
	//=============================================================================================
	// draws the given floor area poly with calculated area in m sq
	//=============================================================================================
	public function drawFloorArea(poly:Vector.<Point>,flr:FloorArea):void
	{
		if (poly==null || poly.length==0)	return;
		
		flr.icon.graphics.clear();
		flr.icon.graphics.beginBitmapFill(FloorPatterns[flr.flooring]);	// pattern type
		var i:int=poly.length-1;
		flr.icon.graphics.moveTo(poly[i].x,poly[i].y);
		for (; i>-1; i--)
			flr.icon.graphics.lineTo(poly[i].x,poly[i].y);
		i=poly.length-1;
		flr.icon.graphics.lineTo(poly[i].x,poly[i].y);
		flr.icon.graphics.endFill();
		
		var tf:TextField = null;
		if (flr.icon.numChildren>0 && flr.icon.getChildAt(0) is TextField) 
			tf = (TextField)(flr.icon.removeChildAt(0));
		else
		{
			tf = new TextField();
			var tff:TextFormat = tf.defaultTextFormat;
			tff.color = 0x000000;
			tf.defaultTextFormat = tff;
			tf.autoSize = "left";
			tf.wordWrap = false;
			tf.selectable = false;
			tf.filters = [new GlowFilter(0xFFFFFF,1,2,2,10)];
		}
		var bnds:Rectangle = flr.icon.getBounds(flr.icon);
		flr.area = calculateArea(poly);
		tf.text = int(flr.area/100)/100+"m sq.";
		tf.x = bnds.left+(bnds.width-tf.width)/2;
		tf.y = bnds.top+(bnds.height-tf.height)/2;
		flr.icon.addChild(tf);
	}//endfunction
	
	//=============================================================================================
	// find cyclics, by walking in tightest possible circles
	//=============================================================================================
	public function findIsolatedAreas():Vector.<Vector.<Point>>
	{
		var timr:uint = getTimer();
		var R:Vector.<Vector.<Point>> = new Vector.<Vector.<Point>>();	// results
		if (Walls.length==0)	return R;
		
		// ----- build adjacency list	(list of list of points)
		var Adj:Vector.<Vector.<Point>> = new Vector.<Vector.<Point>>();
		for (var i:int=Joints.length-1; i>-1; i--)
			Adj.push(new Vector.<Point>());		// init vectors
		for (var j:int=0; j<Walls.length; j++)
		{
			var wall:Wall = Walls[j];			// register adjacency
			Adj[Joints.indexOf(wall.joint1)].push(wall.joint2);
			Adj[Joints.indexOf(wall.joint2)].push(wall.joint1);
		}
		
		// ----- remove hair from adj list
		do {
			var hair:Point = null;
			for (j=Adj.length-1; j>-1 && hair==null; j--)
				if (Adj[j].length==1)	// is hair if only one connection
					hair=Joints[j];
			if (hair!=null)
			{
				for (j=Adj.length-1; j>-1; j--)
					if (Adj[j].indexOf(hair)!=-1)
						Adj[j].splice(Adj[j].indexOf(hair),1);
				if (Adj[Joints.indexOf(hair)].length>0)
					Adj[Joints.indexOf(hair)].pop();
			}
		} while (hair!=null);
		
		// ----- function to register result iff unique
		function addIfUnique(poly:Vector.<Point>):void
		{
			for (var i:int=R.length-1; i>-1; i--)
			{
				var r:Vector.<Point> = R[i];
				if (r.length==poly.length)
				{
					var same:Boolean = true;
					for (var j:int=poly.length-1; j>-1 && same; j--)
						if (r.indexOf(poly[j])==-1)
							same=false;
					if (same) return;
				}
			}
			
			R.push(poly);
		}//endfunction
		
		var s:String = "";
		// ----- function to walk circle from edge, assume path.length>=2
		function walkCircle(pathL:Vector.<Point>,pathR:Vector.<Point>):void
		{
			s+="pathL:"+pathL.length+"  pathR:"+pathR.length+"\n";
			var hasL:Boolean = _walkStep(pathL,true);	// modifys pathL!
			var hasR:Boolean = _walkStep(pathR,false);	// modifys pathR!
			
			if (!hasL && !hasR)	// no path
			{}
			else if (pathL[0]==pathL[pathL.length-1])	// left turn loop found
			{
				pathL.pop();
				addIfUnique(pathL);	// push to result
			}
			else if (pathR[0]==pathR[pathR.length-1])	// right turn loop found
			{
				pathR.pop();
				addIfUnique(pathR);	// push to result
			}
			else
			{
				walkCircle(pathL,pathR);	// continue walking L and R turns
			}
		}//endfunction
		
		function _walkStep(path:Vector.<Point>,turnLeft:Boolean=true):Boolean
		{
			var a:Point = path[path.length-2];	// prev walk point
			var b:Point = path[path.length-1];	// current walk point
			
			if (Joints.indexOf(b)==-1)	return false;	// ERROR~~
			var nxts:Vector.<Point> = Adj[Joints.indexOf(b)];
			
			if (nxts.length<=1)	return false;	// is a dead end
			
			var tightestTurn:Point = null;
			for (var i:int=nxts.length-1; i>-1; i--)
				if (nxts[i]!=a)					// prevent walking backwards
				{
					if (turnLeft)
					{
						if (tightestTurn==null ||
							turnAngle(a,b,nxts[i])<turnAngle(a,b,tightestTurn))
							tightestTurn = nxts[i];
					}
					else
					{
						if (tightestTurn==null ||
							turnAngle(a,b,nxts[i])>turnAngle(a,b,tightestTurn))
							tightestTurn = nxts[i];
					}
				}
			path.push(tightestTurn);
			return true;
		}//endfunction
		
		// ----- walk all walls!
		for (j=0; j<Walls.length; j++)
		{
			wall = Walls[j];
			if (Adj[Joints.indexOf(wall.joint1)].indexOf(wall.joint2)!=-1 && // if can reach (not deleted hair)
				Adj[Joints.indexOf(wall.joint2)].indexOf(wall.joint1)!=-1)
			walkCircle(Vector.<Point>([wall.joint1,wall.joint2]),Vector.<Point>([wall.joint1,wall.joint2]));
		}
		// so how to find isolated islands???
		
		debugStr= "seek t="+(getTimer()-timr)+" R.length="+R.length;
		return R;
	}//endfunction
	
	//=============================================================================================
	// find cyclics, i.e. room floor areas 
	//=============================================================================================
	public var debugStr:String = "";
	public function findIsolatedAreasO():Vector.<Vector.<Point>>
	{
		var R:Vector.<Vector.<Point>> = new Vector.<Vector.<Point>>();	// results
		
		if (Joints.length==0)	return R;
		
		var timr:uint = getTimer();
		
		//-------------------------------------------------------------------------------
		function seek(curJoint:Point,path:Vector.<Point>) : void
		{
			var i:int=0;
			if (path.indexOf(curJoint)!=-1)	// if there is loop
			{	
				var lop:Vector.<Point> = path.slice(path.indexOf(curJoint));
				if (lop.length>2)
				{	
					for (i=R.length-1; i>-1; i--)
					{
						if (polyIsIn(R[i],lop))		// has another smaller loop as result
							return;					// discard this result
						else if (polyIsIn(lop,R[i]))// is being contained
							R.splice(i,1);			// remove bigger loop that contains it
					}
					R.push(lop);		// insert into results
				}
			}
			else 
			{
				path = path.slice();	// duplicate
				path.push(curJoint);
								
				var edges:Vector.<Wall> = connectedToJoint(curJoint);
				for (i=edges.length-1; i>-1; i--)
				{
					var e:Wall = edges[i];
					var jt:Point = null;
					if (e.joint1==curJoint)	jt = e.joint2;
					else					jt = e.joint1;
					if (path.length<2 || path[path.length-2]!=jt)	// not walking back
						seek(jt,path);
				}//endfor
			}//endelse
		}//endfunction
		
		seek(Joints[0],new Vector.<Point>());
		
		debugStr= "seek t="+(getTimer()-timr)+" R.length="+R.length;
		
		return R;
	}//endfunction
	
	//=======================================================================================
	// calculates area of poly by triangulating and summing the triangle areas
	//=======================================================================================
	public static function calculateArea(Poly:Vector.<Point>):Number
	{
		var area:Number = 0;
		var Tris:Vector.<Point> = triangulate(Poly);
		var n:int = Tris.length;
		for (var i:int=0; i<n; i+=3)
		{
			var bux:Number = Tris[i+1].x-Tris[i].x;
			var buy:Number = Tris[i+1].y-Tris[i].y;
			var bvl:Number = Math.sqrt(bux*bux+buy*buy);
			bux/=bvl; buy/=bvl;
			
			var qx:Number = Tris[i+2].x-Tris[i].x;
			var qy:Number = Tris[i+2].y-Tris[i].y;
			var ql:Number = Math.sqrt(qx*qx+qy*qy);
			var proj:Number = qx*bux + qy*buy;
			var normD:Number = Math.sqrt(ql*ql-proj*proj);
			
			area += 0.5*normD*bvl;
		}
		
		return area;
	}//endfunction

	//=======================================================================================
	// triangulate by cutting ears off polygon O(n*n)  slow... just so i can find floorarea
	//=======================================================================================
	public static function triangulate(Poly:Vector.<Point>):Vector.<Point>
	{
		var R:Vector.<Point> = new Vector.<Point>();
		var P:Vector.<Point> = Poly.slice();
		
		while (P.length>3)
		{
			var limit:int = P.length;
			do {
				P.push(P.shift());
				limit--;
			} while (!edgeInPoly(P[0].x,P[0].y,P[2].x,P[2].y,P) && limit>0);	// chk cut line is actually in poly
			if (limit<=0) 
				return new Vector.<Point>();		// error occurred
			R.push(P[0],P[1],P[2]);	// push triangle in result
			P.splice(1,1);			// remove P[1]
		}
		if (P.length==3)
		R.push(P[0],P[1],P[2]);
		return R;
	}//endfunction
	
	//=======================================================================================
	// test if poly is entirely within bigPoly
	//=======================================================================================
	public static function polyIsIn(poly:Vector.<Point>,bigPoly:Vector.<Point>):Boolean
	{
		// ----- test points within or on poly
		for (var i:int=poly.length-1; i>-1; i--)
			if (bigPoly.indexOf(poly[i])==-1 && !pointInPoly(poly[i],bigPoly))
				return false;
		
		// ----- test edges within or on poly
		for (i=poly.length-1; i>-1; i--)
		{
			var b:Point = poly[(i+1)%poly.length];
			var a:Point = poly[i];
			var isEdge:Boolean= bigPoly.indexOf(b)==(bigPoly.indexOf(a)+1)%bigPoly.length || 
								bigPoly.indexOf(a)==(bigPoly.indexOf(b)+1)%bigPoly.length;
			if (!isEdge && !edgeInPoly(a.x,a.y,b.x,b.y,bigPoly))
				return false;
		}
		return true;
	}//endfunction
	
	//=======================================================================================
	// test if edge connecting 2 points is entirely in poly
	//=======================================================================================
	public static function edgeInPoly(ax:Number,ay:Number,bx:Number,by:Number,Poly:Vector.<Point>):Boolean
	{
		var n:int = Poly.length;
		for (var i:int=n-1; i>0; i--)
			if (segmentsIntersectPt(Poly[i].x,Poly[i].y,Poly[i-1].x,Poly[i-1].y,ax,ay,bx,by))
				return false;
		if (segmentsIntersectPt(Poly[0].x,Poly[0].y,Poly[n-1].x,Poly[n-1].y,ax,ay,bx,by))
			return false;
		
		return pointInPoly(new Point((ax+bx)/2,(ay+by)/2),Poly);
	}//endfunction

	//=======================================================================================
	// tests if pt is within polygon
	//=======================================================================================
	public static function pointInPoly(pt:Point,Poly:Vector.<Point>):Boolean
	{
		// ----- find external point (top left)
		var n:int = Poly.length;
		var extPt:Point = new Point(0,0);
		for (var i:int=n-1; i>-1; i--)
		{
			if (Poly[i].x<extPt.x)	extPt.x = Poly[i].x;
			if (Poly[i].y<extPt.y)	extPt.y = Poly[i].y;
		}
		extPt.x-=1;
		extPt.y-=1;
		
		var cnt:int=0;	// count number of intersects
		for (i=n-1; i>0; i--)
			if (segmentsIntersectPt(Poly[i].x,Poly[i].y,Poly[i-1].x,Poly[i-1].y,extPt.x,extPt.y,pt.x,pt.y))
				cnt++;
		if (segmentsIntersectPt(Poly[0].x,Poly[0].y,Poly[n-1].x,Poly[n-1].y,extPt.x,extPt.y,pt.x,pt.y))
			cnt++;
		
		return (cnt%2)==1;
	}//endfunction

	//=======================================================================================
	// returns angle of turn form by the 3 points
	//=======================================================================================
	public static function turnAngle(a:Point,b:Point,c:Point) : Number
	{
		var px:Number = b.x-a.x;
		var py:Number = b.y-a.y;
		var qx:Number = c.x-b.x;
		var qy:Number = c.y-b.y;
		var pl:Number = Math.sqrt(px*px+py*py);
		px/=pl; py/=pl;
		var ql:Number = Math.sqrt(qx*qx+qy*qy);
		qx/=ql; qy/=ql;
		var dp:Number = px*qx+py*qy;
		if (dp<-1) 	dp =-1;
		if (dp>1)	dp = 1;
		var ang:Number = +Math.acos(dp); // in radians
		if (px*qy-py*qx<0)	ang*=-1;
		return ang;
	}
	
	//=======================================================================================
	// find line segments intersect point of lines A=(ax,ay,bx,by) C=(cx,cy,dx,dy)
	// returns null for parrallel segs and point segments, does not detect end points
	//=======================================================================================
	public static function segmentsIntersectPt(ax:Number,ay:Number,bx:Number,by:Number,cx:Number,cy:Number,dx:Number,dy:Number) : Point
	{
		if ((ax==cx && ay==cy) || (ax==dx && ay==dy)) return null;	// false if any endpoints are shared
		if ((bx==cx && by==cy) || (bx==dx && by==dy)) return null;
			
		var avx:Number = bx-ax;
		var avy:Number = by-ay;
		var cvx:Number = dx-cx;
		var cvy:Number = dy-cy;
				
		var al:Number = Math.sqrt(avx*avx + avy*avy);	// length of seg A
		var cl:Number = Math.sqrt(cvx*cvx + cvy*cvy);	// length of seg C
		
		if (al==0 || cl==0 || avx/al==cvx/cl || avy/al==cvy/cl)		return null;
		
		var ck:Number = -1;
		if (avx/al==0)		ck = (ax-cx)/cvx*cl;
		else	ck = (cy-ay + (ax-cx)*avy/avx) / (cvx/cl*avy/avx - cvy/cl);
		
		var ak:Number = -1;
		if (cvx/cl==0)		ak = (cx-ax)/avx*al;
		else	ak = (ay-cy + (cx-ax)*cvy/cvx) / (avx/al*cvy/cvx - avy/al);
			
		if (ak<=0 || ak>=al || ck<=0 || ck>=cl)	return null;
			
		return new Point(ax + avx/al*ak,ay + avy/al*ak);
	}//endfunction
		
}//endclass

class Line
{
	public var joint1:Point;
	public var joint2:Point;
	public var thickness:Number=1;
	public var color:uint=0x666666;
	public var planView:Sprite;					// 
	
	//=======================================================================================
	//
	//=======================================================================================
	public function Line(pt1:Point, pt2:Point):void
	{
		joint1 = pt1;
		joint2 = pt2;
		planView = new Sprite();
	}
	
	//=======================================================================================
	//
	//=======================================================================================
	public function refresh():void
	{
		planView.graphics.clear();
		while (planView.numChildren > 0)	planView.removeChildAt(0);
		drawI(planView, joint1.x, joint1.y, joint2.x, joint2.y,6,true,thickness,color);
	}
	
	//=============================================================================================
	// convenience function to draw the length markings
	//=============================================================================================
	public static function drawI(s:Sprite,ax:Number,ay:Number,bx:Number,by:Number,w:int=6,showLen:Boolean=false,thickness:Number=0,color:uint=0x666666):void
	{
		var vx:Number = bx-ax;
		var vy:Number = by-ay;
		var vl:Number = Math.sqrt(vx*vx+vy*vy);
		var ux:Number = vx/vl;
		var uy:Number = vy/vl;
		w/=2;
		// ----- draw rect for hittest
		s.graphics.lineStyle();
		s.graphics.beginFill(color,0);
		s.graphics.moveTo(ax-uy*w,ay+ux*w);
		s.graphics.lineTo(ax+uy*w,ay-ux*w);
		s.graphics.lineTo(bx+uy*w,by-ux*w);	
		s.graphics.lineTo(bx-uy*w,by+ux*w);
		s.graphics.endFill();
		
		// ----- draw lines
		s.graphics.lineStyle(thickness,color,1);
		s.graphics.moveTo(ax-uy*w,ay+ux*w);
		s.graphics.lineTo(ax+uy*w,ay-ux*w);
		s.graphics.moveTo(bx-uy*w,by+ux*w);
		s.graphics.lineTo(bx+uy*w,by-ux*w);	
		
		if (showLen)
		{
			var tf:TextField = new TextField();
			var tff:TextFormat = tf.defaultTextFormat;
			tff.color = 0x000000;
			tff.font = "arial";
			tf.wordWrap = false;
			tf.autoSize = "left";
			tf.selectable = false;
			tf.text = (int(vl)/100)+"m";
			tf.filters = [new GlowFilter(0xFFFFFF,1,2,2,10)];
			var bmp:Bitmap = new Bitmap(new BitmapData(tf.width,tf.height,true,0x00000000),"auto",true);
			bmp.bitmapData.draw(tf,null,null,null,null,true);
			var rot:Number = Math.atan2(ux,-uy)-Math.PI/2;
			var tx:Number = -0.5*bmp.width;
			var ty:Number = 0.5*bmp.height;
			bmp.x = tx*Math.cos(rot)+ty*Math.sin(rot);
			bmp.y = -(ty*Math.cos(rot)-tx*Math.sin(rot));
			bmp.rotation = rot/Math.PI*180;
			bmp.x += (ax+bx)/2;
			bmp.y += (ay+by)/2;
			s.addChild(bmp);
			var tw:int = Math.max(bmp.width,bmp.height);
			s.graphics.moveTo(ax,ay);
			s.graphics.lineTo(ax+ux*(vl-tw)/2,ay+uy*(vl-tw)/2);
			s.graphics.moveTo(bx,by);
			s.graphics.lineTo(bx-ux*(vl-tw)/2,by-uy*(vl-tw)/2);
		}
		else
		{
			s.graphics.moveTo(ax,ay);
			s.graphics.lineTo(bx,by);
		}
	}//endfunction
	
	
}//endclass

class Wall
{
	public var joint1:Point;
	public var joint2:Point;
	public var thickness:Number;
	public var height:Number;
	public var Doors:Vector.<Door>;
	public var planView:Sprite;					// 
	public var sideView:Sprite;					// 
	public var wallPaper:BitmapData = null;		// wall style
	public var wallPaperId:String = null;		// wallpaper id
	public var wallPaperUnitCost:Number = 0;	// 
	
	public static var WallPapers:Vector.<BitmapData> = Vector.<BitmapData>([new wall01(),new wall02(),new wall03(),new wall04(),new wall05(),
																			new wall06(),new wall07(),new wall08(),new wall09(),new wall10(),
																			new wall11(),new wall12(),new wall13(),new wall14(),new wall15(),
																			new wall16(),new wall17(),new wall18(),new wall19(),new wall20(),
																			new wall21()]);
	
	//=======================================================================================
	//
	//=======================================================================================
	public function Wall(pt1:Point, pt2:Point, thick:Number=10,h:Number=2):void
	{
		joint1 = pt1;
		joint2 = pt2;
		thickness = thick;
		height = h;
		height = 200;
		Doors = new Vector.<Door>();
		planView = new Sprite();
		sideView = new Sprite();
		wallPaper = new BitmapData(1, 1, false, 0xFFFFFF);
	}//endconstr
	
	//=======================================================================================
	//
	//=======================================================================================
	public function addDoor(door:Door):void
	{
		Doors.push(door);
		planView.addChild(door.icon);
		if (door.sideIcon!=null) sideView.addChild(door.sideIcon);
		
	}//endfunction
	
	//=======================================================================================
	//
	//=======================================================================================
	public function removeDoor(door:Door):void
	{
		if (Doors.indexOf(door)!=-1)
		{
			Doors.splice(Doors.indexOf(door),1);
			if (door.icon.parent == this.planView) door.icon.parent.removeChild(door.icon);
			if (door.sideIcon.parent == this.sideView) door.sideIcon.parent.removeChild(door.sideIcon);
		}
	}//endfunction
	
	//=======================================================================================
	// chks if door can be placed on wall
	//=======================================================================================
	public function chkPlaceDoor(pt:Point, width:Number):Point
	{
		var wallV:Point = joint2.subtract(joint1);
		var wallL:Number = wallV.length;
		wallV.normalize(1);
		var proj:Number = (pt.x-joint1.x)*wallV.x + (pt.y-joint1.y)*wallV.y;	// ratio along wall where door is at
		var a:Number = proj/wallL-0.5*width/wallL;	// door span along wallL
		var b:Number = proj/wallL+0.5*width/wallL;
		if (a<0 || b>1)	return null;	//exceed wall limit
		
		for (var i:int=Doors.length-1; i>-1; i--)		// check if overlap other doors
		{
			var c:Number = Doors[i].pivot;
			var d:Number = Doors[i].dir+c;
			if (d<c)
			{
				var tmp:Number = d;
				d = c;
				c = tmp;
			}
			if ((a>c && a<d) || (b>c && b<d))
				return null;
		}
		return new Point(a,b);
	}//endfunction
	
	//=======================================================================================
	// returns perpendicular dist ffom posn to wall, return MAX_VAL if not within wall bounds
	// @param	posn
	// @return
	//=======================================================================================
	public function perpenticularDist(posn:Point):Number
	{
		var wallDir:Point = joint2.subtract(joint1);
		var len:Number = wallDir.length;
		wallDir.x/=len; wallDir.y/=len;
		
		var ptDir:Point = posn.subtract(joint1);
		var proj:Number = ptDir.x*wallDir.x+ptDir.y*wallDir.y;
		if (proj<0 || proj>len) return Number.MAX_VALUE;
		
		return Math.sqrt(ptDir.x*ptDir.x+ptDir.y*ptDir.y - proj*proj);
	}//endfunction
	
	//=======================================================================================
	// returns the 4 corner positions of the wall if it were standalone
	//=======================================================================================
	public function wallBounds(from2:Boolean=false):Vector.<Point>
	{
		var j1:Point = joint1;
		var j2:Point = joint2;
		if (from2)
		{
			j2 = joint1;
			j1 = joint2;
		}
		
		var dv:Point = j2.subtract(j1);
		var f:Number = 0.5*thickness/dv.length;
		dv.x*=f; dv.y*=f;
		
		return Vector.<Point>([	new Point(j1.x-dv.x+dv.y,j1.y-dv.y-dv.x),
								new Point(j2.x+dv.x+dv.y,j2.y+dv.y-dv.x),
								new Point(j2.x+dv.x-dv.y,j2.y+dv.y+dv.x),
								new Point(j1.x-dv.x-dv.y,j1.y-dv.y+dv.x)]);
	}//endfunction
	
	//=======================================================================================
	// 
	//=======================================================================================
	public function updateSideView():void
	{
		trace("updateSideView()");
		while (sideView.numChildren > 0)	sideView.removeChildAt(0);
		var w:Number = joint1.subtract(joint2).length;
		sideView.graphics.clear();
		sideView.graphics.beginBitmapFill(wallPaper);
		sideView.graphics.drawRect( -w/2, -height/2, w, height);
		sideView.graphics.endFill();
		
		FloorPlan.drawI(sideView, -w / 2, -height / 2, w / 2, -height / 2, 6, true);
		FloorPlan.drawI(sideView, -w / 2,  height / 2, w / 2,  height / 2, 6, true);
		FloorPlan.drawI(sideView, -w / 2, -height / 2,-w / 2,  height / 2, 6, true);
		FloorPlan.drawI(sideView,  w / 2, -height / 2, w / 2,  height / 2, 6, true);
		
		for (var i:int = 0; i < Doors.length; i++ )
		{
			var door:Door = Doors[i];
			if (isNaN(door.height)) door.height = 0;
			trace("  - door pivot="+door.pivot+" dir="+door.dir +" height="+door.height+" sideIco="+door.sideIcon);
			if (door.sideIcon != null)
			{
				door.sideIcon.x = w*(door.pivot + 0.5*door.dir)-w/2;
				door.sideIcon.rotation = 0;
				door.sideIcon.width = door.dir*w;
				door.sideIcon.height = door.height*height;
				door.sideIcon.y = door.bottom * height - height / 2 - door.sideIcon.height / 2;
				trace("door.sideIcon  w="+door.sideIcon.width+"  h="+door.sideIcon.height+"  ");
				sideView.addChild(door.sideIcon);
			}
			else
				trace("door.sideIcon="+door.sideIcon+"!!");
			
			/*
			var ptA:Point = new Point(	joint1.x * (1 - r1) + joint2.x * r1,
										joint1.y * (1 - r1) + joint2.y * r1);
			var ptB:Point = new Point(	joint1.x * (1 - r2) + joint2.x * r2,
										joint1.y * (1 - r2) + joint2.y * r2);
			*/
		}
	}//endfunction
	
	//=======================================================================================
	// 
	//=======================================================================================
	public function updateDoorWithIconPosn(door:Door):void
	{
		var w:Number = joint1.subtract(joint2).length;
		door.dir = door.sideIcon.width / w;
		if (door.sideIcon.scaleX < 0)	door.dir *= -1;
		door.pivot = (door.sideIcon.x+w/2 - door.dir * w/2) / w;
		door.bottom = (door.sideIcon.height / 2 + door.sideIcon.y+height/2) / height;
		door.height = door.sideIcon.height/height;
		trace("door.dir="+door.dir+"  door.pivot="+door.pivot+"  door.bottom="+door.bottom);
	
		if (door.dir > 0)
		{
			if (door.pivot < 0) door.pivot = 0;
			if (door.pivot + door.dir > 1) door.pivot = 1 - door.dir;
		}
		else
		{
			if (door.pivot + door.dir < 0) door.pivot = -door.dir;
			if (door.pivot > 1) door.pivot = 1;
		}
		if (door.bottom > 1) door.bottom = 1;
		
	}//endfunction
	
	//=======================================================================================
	// 
	//=======================================================================================
	public function get area():Number
	{
		return joint1.subtract(joint2).length * height;
	}//endfunction
}//endclass

class FloorArea
{
	public var label:String = "";	// the floor area label
	public var area:Number = 0;		// area in m sq
	public var flooring:int=0;		// the floor texture 
	public var icon:Sprite=null;	// floor area icon mc
	
	public function FloorArea(floorType:int=0):void
	{
		icon = new Sprite();
		flooring = floorType;
	}
}//endclass

class Item
{
	public var icon:DisplayObject = null;
	public var color:int = 0;
	
	public var id:String = null;
	public var name:String = null;
	public var price:Number = 0;
	
	public var frontUrl:String = null;
	public var backUrl:String = null;
	public var leftUrl:String = null;
	public var rightUrl:String = null;
	public var upUrl:String = null;
	public var downUrl:String = null;
	
	public var length:Number = 0;		// in meters
	public var width:Number = 0;		// in meters
	public var height:Number = 0;		// in meters
	
	
	public function Item(ico:Sprite,frame:int=0):void
	{
		icon = ico;
		color = frame;
	}
}//endclass

class Door
{
	public var id:String = null;
	public var name:String = null;
	public var cost:Number = 0;
	public var pivot:Number=0.5;	// a ratio from joint1 to joint2 of wall	
	public var dir:Number=0.25;		// an added ratio relative to pivot, should i make this absolute
	public var height:Number = 1;	// height ratio relative to wall height
	public var bottom:Number = 1;
	public var icon:Sprite = null;
	public var sideIcon:Sprite = null;
	
	public function Door(piv:Number,wid:Number,ico:Sprite,sideIco:Sprite=null):void
	{
		pivot = piv;
		dir = wid;
		icon = ico;
		sideIcon = sideIco;
	}//endfunction
}//endclass