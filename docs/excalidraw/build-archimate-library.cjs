/* Build original native stencils from the documented ArchiMate notation. */
module.exports = function buildArchiMateLibrary(ea) {
  let serial = 0;
  const id = () => `a4${(++serial).toString(36).padStart(6, "0")}`;
  const setup = () => {
    ea.reset();
    Object.assign(ea.style, {
      strokeColor: "#1e1e1e", backgroundColor: "transparent", fillStyle: "solid",
      strokeWidth: 1, strokeStyle: "solid", roughness: 0, opacity: 100,
      roundness: null, fontFamily: 5, fontSize: 22, textAlign: "center",
      verticalAlign: "middle", startArrowHead: null, endArrowHead: null,
    });
  };
  const line = points => ea.addLine(points, id());
  const rect = (x,y,w,h) => ea.addRect(x,y,w,h,id());
  const circle = (x,y,d) => ea.addEllipse(x,y,d,d,id());
  const text = (x,y,label) => ea.addText(x,y,label,{},id());
  const typeData = type => ({ archimate: { version: "4", type } });
  const items = [];
  const addItem = (name, type) => {
    ea.addToGroup(ea.getElements().map(e => e.id));
    items.push({
      id: `archimate4-${type.toLowerCase()}-v1`, name: `ArchiMate · ${name}`,
      status: "unpublished", created: 1790208000000,
      elements: JSON.parse(JSON.stringify(ea.getElements())),
    });
  };
  for (const type of ["Goal","Principle","Requirement","Artifact","Process","ApplicationComponent","DataObject"]) {
    setup();
    const motivation = ["Goal","Principle","Requirement"].includes(type);
    const body = motivation
      ? line([[12,0],[248,0],[260,12],[260,98],[248,110],[12,110],[0,98],[0,12],[12,0]])
      : rect(0,0,260,110);
    if (type === "Process") ea.getElement(body).roundness = {type:3};
    const label = text(0,0,type === "ApplicationComponent" ? "Application\ncomponent" : type === "DataObject" ? "Data Object" : type);
    const t = ea.getElement(label);
    t.x = (260-t.width)/2;
    t.y = (110-t.height)/2 + 5;
    t.customData = typeData(type);
    if (!motivation) {
      t.containerId = body;
      ea.getElement(body).boundElements = [{id:label,type:"text"}];
    }
    if (type === "Goal") {
      circle(225,10,22); circle(231,16,10);
      line([[236,21],[246,10]]);
    } else if (type === "Principle") {
      const box=rect(225,10,23,24); ea.getElement(box).roundness={type:3};
      line([[236.5,14],[236.5,24]]); circle(235.5,28,2);
    } else if (type === "Requirement") {
      line([[231,11],[251,11],[243,31],[223,31],[231,11]]);
    } else if (type === "Artifact") {
      line([[227,10],[241,10],[249,18],[249,34],[227,34],[227,10]]);
      line([[241,10],[241,18],[249,18]]);
    } else if (type === "Process") {
      line([[222,17],[236,17],[236,11],[250,23],[236,35],[236,29],[222,29],[222,17]]);
    } else if (type === "ApplicationComponent") {
      rect(230,10,20,24); rect(224,14,12,6); rect(224,24,12,6);
    } else {
      rect(223,12,26,20); line([[223,18],[249,18]]);
    }
    addItem(type === "ApplicationComponent" ? "Application component" : type === "DataObject" ? "Data Object" : type,type);
  }
  for (const [type,style,head] of [
    ["Access","dotted","arrow"],
    ["Realization","dotted","triangle_outline"],
    ["Association","solid",null],
  ]) {
    setup();
    ea.style.strokeStyle=style;
    const arrow=ea.addArrow([[0,0],[260,0]],{startArrowHead:null,endArrowHead:head},id());
    ea.getElement(arrow).startBinding=null;
    ea.getElement(arrow).endBinding=null;
    ea.getElement(arrow).customData=typeData(type);
    items.push({id:`archimate4-${type.toLowerCase()}-v1`,name:`ArchiMate · ${type}`,
      status:"unpublished",created:1790208000000,elements:JSON.parse(JSON.stringify(ea.getElements()))});
  }
  return {type:"excalidrawlib",version:2,source:"https://excalidraw.com",libraryItems:items};
};
