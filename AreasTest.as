package 
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	
	[SWF(width = "1024", height = "768", backgroundColor = "#FFFFFF", frameRate = "30")];
	
	/**
	 * ...
	 * @author Minjmirage
	 */
	public class AreasTest extends Sprite
	{
		private var flrAreas:FloorAreas = null;		// 
		
		private var enterFrameFn:Function = null;	// custom fn to exec every frame
		private var mouseUpFn:Function = null;		// custom fn to exec on mouse up
		
		private var numWalls:int = 0;
		
		/**
		 * 
		 */
		public function AreasTest():void
		{
			flrAreas = new FloorAreas();
			addChild(flrAreas.overlay);
			
			stage.addEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
			stage.addEventListener(MouseEvent.MOUSE_UP,mouseUpHandler);
			stage.addEventListener(Event.ENTER_FRAME,enterFrameHandler);
		}//endconstr
		
		/**
		 * 
		 */
		private function mouseDownHandler(ev:MouseEvent):void
		{
			numWalls = flrAreas.Walls.length;
			var njt:Point = flrAreas.nearestJoint(new Point(mouseX,mouseY),10);
			if (njt!=null && flrAreas.selected==njt)	
				startShiftJoint(njt);
			else			
				startDrawWall();
		}//endfunction
		
		/**
		 * 
		 */
		private function mouseUpHandler(ev:MouseEvent):void
		{
			if (mouseUpFn!=null)	mouseUpFn();
			
			if (flrAreas.Walls.length==numWalls)
			{
				flrAreas.selected = flrAreas.nearestJoint(new Point(mouseX,mouseY),10);
				flrAreas.refresh();
			}
		}//endfunction
		
		/**
		 * 
		 */
		private function enterFrameHandler(ev:Event):void
		{
			if (enterFrameFn!=null)	enterFrameFn();
		}//endfunction
		
		/**
		 * start wall joint move
		 */
		private function startShiftJoint(jt:Point):void
		{
			enterFrameFn = function():void
			{
				if (jt!=null)
				{
					jt.x = mouseX;
					jt.y = mouseY;
					flrAreas.refresh();
				}//endif
			}//endfunction
			
			mouseUpFn = function():void
			{
				var near:Point = flrAreas.nearestJoint(jt,10);
				if (near!=null)	
				{
					flrAreas.replaceJointWith(jt,near);
					flrAreas.refresh();
				}
				enterFrameFn = null;
				mouseUpFn = null;
			}
		}//endfunction
		
		/**
		 * start draw new wall
		 */
		private function startDrawWall(thickness:int=10):void
		{
			var mouseDownPt:Point = new Point(mouseX,mouseY);
			var jta:Point = flrAreas.nearestJoint(new Point(mouseX,mouseY),10);
			if (jta==null) jta = new Point(mouseX,mouseY);
			var W:Vector.<Wall> = Vector.<Wall>([flrAreas.createWall(jta,mouseDownPt,thickness)]);
			
			mouseUpFn = function():void
			{
				var near:Point = flrAreas.nearestJoint(mouseDownPt,10);
				if (near!=null)	
				{
					if (near==W[0].joint1)
						flrAreas.removeWall(W[0]);
					else
						flrAreas.replaceJointWith(mouseDownPt,near);
				}
				mouseDownPt = null;
				
				while (W.length>0)
				{
					var wall:Wall = W.shift();
					var collided:Wall = flrAreas.chkWallCollide(wall);
					if (collided!=null)
					{
						var crs:Point = 
						FloorAreas.segmentsIntersectPt(	collided.joint1.x,collided.joint1.y,
														collided.joint2.x,collided.joint2.y,
														wall.joint1.x,wall.joint1.y,
														wall.joint2.x,wall.joint2.y);
						flrAreas.removeWall(wall);
						W.push(flrAreas.createWall(wall.joint1,crs,wall.thickness));
						W.push(flrAreas.createWall(wall.joint2,crs,wall.thickness));
						flrAreas.removeWall(collided);
						flrAreas.createWall(collided.joint1,crs,collided.thickness);
						flrAreas.createWall(collided.joint2,crs,collided.thickness);
					}
				}
				flrAreas.refresh();
				
				mouseUpFn = null;
				enterFrameFn = null;
			}//endfunction
		
			enterFrameFn = function():void
			{
				if (mouseDownPt!=null)
				{
					mouseDownPt.x = mouseX;
					mouseDownPt.y = mouseY;
					flrAreas.refresh();
				}//endif
			}//endfunction			
		}//endfunction
	}//endclass
}

import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.Sprite;
import flash.filters.GlowFilter;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.utils.getTimer;

class FloorAreas
{
	public var Joints:Vector.<Point>;			// list of wall joints
	public var Walls:Vector.<Wall>;				// list of walls connecting 2 joints
	public var floorAreas:Vector.<FloorArea>;	// list of floor areas already on the stage

	public var overlay:Sprite = null;
	private var wallsOverlay:Sprite = null;
	private var jointsOverlay:Sprite = null;
	
	public var selected:* = null;
	
	/**
	 * 
	 */
	public function FloorAreas():void
	{
		Joints = new Vector.<Point>();
		Walls = new Vector.<Wall>();
		floorAreas = new Vector.<FloorArea>();
		
		overlay = new Sprite();
		overlay.buttonMode = true;
		wallsOverlay = new Sprite();
		overlay.addChild(wallsOverlay);
		jointsOverlay = new Sprite();
		overlay.addChild(jointsOverlay);
	}//endfunction

	/**
	 * @return	the bounding rectangle of the entire floor area
	 */
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

	/**
	 * @param	pt1		starting wall end joint
	 * @param	pt2		ending wall end joint
	 * @param	width	
	 * @return	the new created wall to the floorplan
	 */
	public function createWall(pt1:Point, pt2:Point, thickness:Number=10):Wall
	{
		if (Joints.indexOf(pt1)==-1)	Joints.push(pt1);
		if (Joints.indexOf(pt2)==-1)	Joints.push(pt2);
		var wall:Wall = new Wall(pt1, pt2, thickness);
		Walls.push(wall);
		wallsOverlay.addChild(wall.planView);
		return wall;
	}//endfunction

	/**
	 * cleanly remove wall and its unused joints
	 * @param	wall
	 */
	public function removeWall(wall:Wall):void
	{
		if (Walls.indexOf(wall)!=-1)	Walls.splice(Walls.indexOf(wall),1);
		if (wallsOverlay.contains(wall.planView))	wallsOverlay.removeChild(wall.planView);
		
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
	 
	/**
	 * @param	posn
	 * @param	cutOff distance
	 * @return	the nearest joint to given posn, or null
	 */
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

	/**
	 * replace joint with given new joint, used for snapping together wall joints
	 * @param	jt
	 * @param	njt
	 */
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

	/**
	 * @param	posn
	 * @param	cutOff
	 * @return	the nearest wall to this position, where posn cannot be joint1 or joint2
	 */
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

	/**
	 * @param	wall
	 * @return	wall that collided with given wall or null
	 */
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

	/**
	 * @param	wall
	 * @param	pt
	 * @return	 position of point projected onto wall
	 */
	public function projectedWallPosition(wall:Wall, pt:Point) : Point
	{
		var vpt:Point = pt.subtract(wall.joint1);
		var dir:Point = wall.joint2.subtract(wall.joint1);
		dir.normalize(1);
		var k:Number =dir.x*vpt.x + dir.y*vpt.y;

		return new Point(wall.joint1.x + dir.x*k, wall.joint1.y + dir.y * k);;
	}//endfunction

	/**
	 * redraws all the walls and floor areas
	 */
	public function refresh():void
	{
		var i:int=0;
		overlay.graphics.clear();
		overlay.graphics.lineStyle(0);
		
		// ----- debug draws the wall joint star ------------------------------
		var Stars:Vector.<Vector.<Number>> = new Vector.<Vector.<Number>>();
		for (i=Joints.length-1; i>-1; i--)
		{
			var star:Vector.<Number> = getWallJointStar(Joints[i]);
			Stars.unshift(star);
			if (star.length>2)
			{
				for (var j:int=star.length-2; j>-1; j-=2)
				{
					overlay.graphics.moveTo(star[0],star[1]);
					overlay.graphics.lineTo(star[j],star[j+1]);
				}
			}
		}
		
		// ----- redraw all walls ---------------------------------------------
		for (i=Walls.length-1; i>-1; i--)
			drawWall(Walls[i],Stars);
		
		// ----- redraw enclosed floor areas ----------------------------------
		var A:Vector.<Vector.<Point>> = findIsolatedAreas();
		while (floorAreas.length<A.length)
		{
			var fa:FloorArea = new FloorArea(floorAreas.length);
			floorAreas.push(fa);
			overlay.addChildAt(fa.planView,0);
		}
		while (floorAreas.length>A.length)
			overlay.removeChild(floorAreas.pop().planView);
		for (i=A.length-1; i>-1; i--)	// draw for each floorArea
			floorAreas[i].drawFloorArea(A[i]);

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
	}//endfunction

	/**
	 * draws given wall with any door and windows on it
	 * @param	wall
	 */
	public function drawWall(wall:Wall,Stars:Vector.<Vector.<Number>>):void
	{
		// ----- draw wall bounds
		var wallB:Vector.<Point> = wall.wallBounds(false);
		
		var ipt:Point = null;
		var i:int=0;
		
		var star1:Vector.<Number> = Stars[Joints.indexOf(wall.joint1)];
		for (i=star1.length-2; i>-1; i-=2)
		{
			ipt = segmentsIntersectPt(	wallB[0].x,wallB[0].y,wallB[1].x,wallB[1].y,
										star1[0],star1[1],star1[i],star1[i+1]);
			if (ipt!=null)	wallB[0] = ipt;
			ipt = segmentsIntersectPt(	wallB[3].x,wallB[3].y,wallB[2].x,wallB[2].y,
										star1[0],star1[1],star1[i],star1[i+1]);
			if (ipt!=null)	wallB[3] = ipt;
		}
		
		var star2:Vector.<Number> = Stars[Joints.indexOf(wall.joint2)];
		for (i=star2.length-2; i>-1; i-=2)
		{
			ipt = segmentsIntersectPt(	wallB[0].x,wallB[0].y,wallB[1].x,wallB[1].y,
										star2[0],star2[1],star2[i],star2[i+1]);
			if (ipt!=null)	wallB[1] = ipt;
			ipt = segmentsIntersectPt(	wallB[3].x,wallB[3].y,wallB[2].x,wallB[2].y,
										star2[0],star2[1],star2[i],star2[i+1]);
			if (ipt!=null)	wallB[2] = ipt;
		}
		
		// ----- draws the calculated wallB
		wall.planView.graphics.clear();
		while (wall.planView.numChildren>0)	wall.planView.removeChildAt(0);
		if (selected==wall)		wall.planView.graphics.beginFill(0xFF6600,0.5);
		else					wall.planView.graphics.beginFill(0x000000,0.5);
		wall.planView.graphics.lineStyle(0,0);
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
	}//endfunction
	
	/**
	 * returns the dividing bisectors of wall joint
	 * @param	jt
	 * @return	[x0,y0,x1,y1,x2,y2,...xn,yn] where each (x0,y0 , xi,yi) is bisecting line
	 */
	private function getWallJointStar(jt:Point):Vector.<Number>
	{
		var V:Vector.<Point> = new Vector.<Point>();
		var _p0:Point = new Point(0,-1000);
		var p0:Point = new Point(0,0);
		for (var i:int=Walls.length-1; i>-1; i--)
		{
			var insJt:Point = null;
			if (Walls[i].joint1==jt)	insJt = Walls[i].joint2;
			if (Walls[i].joint2==jt)	insJt = Walls[i].joint1;
			if (insJt!=null)
			{
				insJt = insJt.subtract(jt);
				insJt.normalize(1);
				
				// ----- binary sort insert 
				var p:int=0;
				var q:int=V.length-1;
				while (p<=q)
				{
					var m:int = (p+q)/2;
					if (turnAngle(_p0,p0,V[m])<turnAngle(_p0,p0,insJt))
						p=m+1;
					else
						q=m-1;
				}
				V.splice(p,0,insJt);
			}
		}
		/*
		var B:Vector.<Number> = new Vector.<Number>();
		for (i=V.length-1; i>-1; i--)
		{
			B.unshift(V[i].x*100+jt.x,V[i].y*100+jt.y);
		}
		B.unshift(jt.x,jt.y);
		return B;
		*/
		
		// ----- find bisectors for each wall joint sector
		var B:Vector.<Number> = new Vector.<Number>();
		for (i=V.length-1; i>-1; i--)
		{
			var a:Point = V[i];
			var b:Point = V[(i+1)%V.length];
			var dp:Number = a.x*b.x+a.y*b.y;
			if (dp<-1) dp = -1;
			if (dp>1) dp = 1;
			var ang:Number = Math.acos(dp);
			if (a.x*b.y-a.y*b.x>0)	ang = Math.PI*2-ang;
			ang/=2;
			// ----- do rotation on a by ang/2
			var sinA:Number = Math.sin(ang);
			var cosA:Number = Math.cos(ang);
			var cx:Number = a.x*cosA+a.y*sinA;
			var cy:Number = a.y*cosA-a.x*sinA;
			B.unshift(-cx*100+jt.x,-cy*100+jt.y);
		}
		B.unshift(jt.x,jt.y);
		return B;
		
	}//endfunction
	
	/**
	* convenience function to extend wall ends so they intersect nicely at acute angles
	*/
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

	/**
	* finds all walls connected to given wall joint
	*/
	private function connectedToJoint(pt:Point):Vector.<Wall>
	{
		var W:Vector.<Wall> = new Vector.<Wall>();
		for (var i:int=Walls.length-1; i>-1; i--)
			if (Walls[i].joint1==pt || Walls[i].joint2==pt)
				W.unshift(Walls[i]);
		return W;
	}//endfunction

	/**
	* find cyclics, by walking in tightest possible circles
	*/
	public function findIsolatedAreas():Vector.<Vector.<Point>>
	{
		var timr:uint = getTimer();
		var R:Vector.<Vector.<Point>> = new Vector.<Vector.<Point>>();	// results
		if (Walls.length==0)	return R;

		// ----- build adjacency list	(list of list of points)
		var Adj:Vector.<Vector.<Point>> = new Vector.<Vector.<Point>>();
		for (var i:int=Joints.length-1; i>-1; i--)
			Adj.push(new Vector.<Point>());		// init vectors
		for (var j:int=Walls.length-1; j>-1; j--)
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

		trace("seek t="+(getTimer()-timr)+" R.length="+R.length);
		return R;
	}//endfunction
	
	private static var drawTf:TextField = null;
	
	/**
	 * convenience function to draw the length markings
	 * @param	s		target to draw on
	 * @param	ax		point a
	 * @param	ay		point a
	 * @param	bx		point b
	 * @param	by		point b
	 * @param	w		stop end width
	 * @param	showLen	whether to show length markings
	 */
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
			if (drawTf==null)
			{
				drawTf = new TextField();
				var tff:TextFormat = drawTf.defaultTextFormat;
				tff.size = 22;
				tff.color = 0x000000;
				tff.font = "arial";
				drawTf.defaultTextFormat = tff;
				drawTf.wordWrap = false;
				drawTf.autoSize = "left";
				drawTf.selectable = false;
				drawTf.filters = [new GlowFilter(0xFFFFFF,1,2,2,10)];
			}
			drawTf.text = (int(vl)/100)+"m";
			var bmp:Bitmap = new Bitmap(new BitmapData(drawTf.width,drawTf.height,true,0x00000000),"auto",true);
			bmp.bitmapData.draw(drawTf,null,null,null,null,true);
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

	/**
	* calculates area of poly by triangulating and summing the triangle areas
	*/
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

	/**
	* triangulate by cutting ears off polygon O(n*n)  slow... just so i can find floorarea
	*/
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

	/**
	* test if poly is entirely within bigPoly
	*/
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

	/**
	* test if edge connecting 2 points is entirely in poly
	*/
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

	/**
	* tests if pt is within polygon
	*/
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

	/**
	 * @param	a	start pt
	 * @param	b	mid pt
	 * @param	c	end pt
	 * @return	angle of turn at b, going from a->b->c 
	 */
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
	}//endfunction

	/**
	* find line segments intersect point of lines A=(ax,ay,bx,by) C=(cx,cy,dx,dy)
	* returns null for parrallel segs and point segments, does not detect end points
	*/
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

class Wall
{
	public var joint1:Point;
	public var joint2:Point;
	public var thickness:Number;
	public var height:Number;
	
	public var planView:Sprite = null;
	
	//=======================================================================================
	//
	//=======================================================================================
	public function Wall(pt1:Point, pt2:Point, thick:Number=10,h:Number=2):void
	{
		joint1 = pt1;
		joint2 = pt2;
		thickness = thick;
		height = h;
		
		planView = new Sprite();
	}//endconstr

	/**
	 * @param	posn
	 * @return	perpendicular dist ffom posn to wall, return MAX_VAL if not within wall bounds
	 */
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
}//endclass

class FloorArea
{
	public var label:String = "";	// the floor area label
	public var area:Number = 0;		// area in m sq
	public var flooring:int=0;		// the floor texture
	
	public var planView:Sprite=null;	// floor area icon mc
	
	private var tf:TextField = null;
	
	private static var FloorPatterns:Vector.<BitmapData> = null;
	
	public function FloorArea(floorType:int=0):void
	{
		planView = new Sprite();
		flooring = floorType;
		
		if (FloorPatterns==null)
		FloorPatterns =  Vector.<BitmapData>([	new Floor1(),
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
		
		tf = new TextField();
		var tff:TextFormat = tf.defaultTextFormat;
		tff.color = 0x000000;
		tf.defaultTextFormat = tff;
		tf.autoSize = "left";
		tf.wordWrap = false;
		tf.selectable = false;
		tf.filters = [new GlowFilter(0xFFFFFF,1,2,2,10)];
		planView.addChild(tf);
	}//endconstr
	
	//=============================================================================================
	// draws the given floor area poly with calculated area in m sq
	//=============================================================================================
	public function drawFloorArea(poly:Vector.<Point>):void
	{
		if (poly==null || poly.length==0)	return;

		planView.graphics.clear();
		planView.graphics.beginBitmapFill(FloorPatterns[flooring%FloorPatterns.length]);	// pattern type
		var i:int=poly.length-1;
		planView.graphics.moveTo(poly[i].x,poly[i].y);
		for (; i>-1; i--)
			planView.graphics.lineTo(poly[i].x,poly[i].y);
		i=poly.length-1;
		planView.graphics.lineTo(poly[i].x,poly[i].y);
		planView.graphics.endFill();

		var bnds:Rectangle = planView.getBounds(planView);
		area = FloorAreas.calculateArea(poly);
		tf.text = int(area/100)/100+"m sq.";
		tf.x = bnds.left+(bnds.width-tf.width)/2;
		tf.y = bnds.top+(bnds.height-tf.height)/2;
	}//endfunction
}//endclass

