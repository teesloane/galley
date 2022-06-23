// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {Uploaders} from './uploaders.js'
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// hooks
//
let hooks = {}

// This hooks is responsible for making text areas look the same as you type.
hooks.MaintainAttrs = {
  mounted() {
    handleTextAreaResizing()
    this.prevAttrs = this.attrs().map(name => [name, this.el.getAttribute(name)])
  },

  attrs(){ return this.el.getAttribute("data-attrs").split(", ") },
  beforeUpdate(){
    handleTextAreaResizing()
    this.prevAttrs = this.attrs().map(name => [name, this.el.getAttribute(name)])
    this.prevAttrs.forEach(([name, val]) => this.el.setAttribute(name, val))
  },
  updated(){
    this.prevAttrs.forEach(([name, val]) => this.el.setAttribute(name, val))
  }
}

hooks.ShowTextAreaCount = {
  mounted() {
    let ta = document.getElementById(this.el.id)
    let charCountEl = document.getElementById("notes-count")
    ta.addEventListener("input", (event) => {
      const target = event.currentTarget;
      const maxLength = target.getAttribute("maxlength");
      const currentLength = target.value.length;

      if (currentLength >= maxLength) {
        charCountEl.textContent = maxLength
        return
      }
      charCountEl.textContent = currentLength
    })
  },
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks,
  // setup alpine js
  dom: {
    onBeforeElUpdated(from, to) {
      if (from._x_dataStack) {
        window.Alpine.clone(from, to)
      }
    }
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()


// textarea hacking
function handleTextAreaResizing() {
  const tx = document.getElementsByTagName("textarea");
  for (let i = 0; i < tx.length; i++) {
    tx[i].setAttribute("style", "height:" + (tx[i].scrollHeight) + "px;overflow-y:hidden;");
    tx[i].addEventListener("input", function () {
      this.style.height = "auto";
      this.style.height = (this.scrollHeight) +  "px";
    }, false);
  }
}

const addInstructionBtn = document.getElementById("add-instruction-btn")
if(addInstructionBtn) {
  addInstructionBtn.addEventListener("click", () => {
    handleTextAreaResizing()
  })
}


// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

