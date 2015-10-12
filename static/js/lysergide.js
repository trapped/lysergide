//$('#side-menu').metisMenu();

//Loads the correct sidebar on window load,
//collapses the sidebar on window resize.
// Sets the min-height of #page-wrapper to window size
$(window).bind("load resize", function() {
  width = (this.window.innerWidth > 0) ? this.window.innerWidth : this.screen.width;
  if (width < 768) {
    $('div.navbar-collapse').addClass('collapse');
  } else {
    $('div.navbar-collapse').removeClass('collapse');
  }
  height = (this.window.innerHeight > 0) ? this.window.innerHeight : this.screen.height;
  if (height < 1) height = 1;
  $("#page-wrapper").css("min-height", height);
});

var lys = {};

lys.page_data = {
  version: undefined,
  user: undefined,
  repo: undefined,
  build: undefined
};

lys.fa_icon = function(e) {
  switch(e) {
    case 'success':   return {icon: 'check',    color: 'green'};
    case 'failed':    return {icon: 'warning',  color: 'firebrick'};
    case 'scheduled': return {icon: 'calendar', color: ''};
    case 'working':   return {icon: 'gear',     color: ''};
    default:          return {icon: 'gear',     color: ''};
  }
};

lys.handleEvent = function(e) {
  switch(e.msg.type) {
    case 'reload':
      window.location.reload(true);
      break;
    case 'build_create':
      console.log('adding build');
      var elems = document.getElementsByClassName('lys-builds');
      for(i = 0; i < elems.length; i++) {
        if(elems[i].classList.contains('list-group')) {
          var new_item = elems[i].insertBefore(document.createElement('a'), elems[i].childNodes[0]);
          new_item.className = 'list-group-item';
          new_item.setAttribute('href', '/' + e.msg.user + '/' + e.msg.repo + '/builds/' + e.msg.build.number);
          new_item.innerText = ' ' + e.msg.repo + ' ';
          var icon = new_item.insertBefore(document.createElement('i'), new_item.childNodes[0]);
          icon.className = 'fa fa-' + lys.fa_icon(e.msg.build.status).icon + ' fa-fw';
          icon.style.color = lys.fa_icon(e.msg.build.status).color;
          var number = new_item.appendChild(document.createElement('b'));
          number.className = 'pull-left';
          number.innerText = '#' + e.msg.build.number;
          var date = new_item.appendChild(document.createElement('span'));
          date.className = 'pull-right text-muted small lys-date';
          date.innerHTML = '<em>' + e.msg.build.date + '</em>';
        }
      }
      break;
    case 'build_update':
      console.log('updating build');
      var elems = document.getElementsByClassName('lys-builds');
      for(i = 0; i < elems.length; i++) {
        if(elems[i].classList.contains('list-group')) {
          for(ii = 0; ii < elems[i].childNodes.length; ii++) {
            if(elems[i].childNodes[ii].getAttribute === undefined) {
              continue;
            }
            if(elems[i].childNodes[ii].getAttribute('href') === ('/' + e.msg.user + '/' + e.msg.repo + '/builds/' + e.msg.build.number)) {
              elems[i].childNodes[ii].firstElementChild.className = 'fa fa-' + lys.fa_icon(e.msg.build.status).icon + ' fa-fw';
              elems[i].childNodes[ii].firstElementChild.style.color = lys.fa_icon(e.msg.build.status).color;
              elems[i].childNodes[ii].getElementsByClassName('lys-date')[0].innerHTML = '<em>' + e.msg.build.date ? e.msg.build.date : '' + '</em>';
            }
          }
        }
      }
      break;
    case 'repo_update':
      console.log('updating repo');
      var elems = document.getElementsByClassName('repo_name');
      for(i = 0; i < elems.length; i++) {
        elems[i].style.color = e.msg.public ? 'green' : '';
      }
      break;
  }
};

lys.handle = function(data) {
  if(!this.initialized) {
    console.log('remote ver.', data.ver);
    if(lys.page_data.version === undefined) {
      lys.page_data.version = data.ver;
    } else if(lys.page_data.version != data.ver) {
      location.reload(true);
    }
    this.initialized = true;
  } else {
    switch(data.type) {
      case 'error':     console.log('error:', data.err, data.msg); break;
      case 'success':   console.log('success:', data.msg); break;
      case 'msg':       lys.handleEvent(data); break;
      case 'keepalive': console.log('keepalive'); break;
      default:          console.log('unknown msg type', data.type);
    }
  }
};

lys.setupWs = function() {
  lys.ws           = new WebSocket('ws' + (window.location.protocol == 'https:' ? 's' : '') + '://' + window.location.host + '/realtime');
  lys.ws.onopen    = function()  {
    console.log('websocket opened');
    if(document.getElementsByClassName('lys-builds').length > 0) {
      lys.ws.send('sub builds');
    }
    var logs = document.getElementsByClassName('lys-build-log');
    if(logs.length > 0) {
      for(var i = 0; i < logs.length; i++) {
        lys.ws.send('sub build_log ' + logs[i].getAttribute('lys_build'));
      }
    }
    if(lys.page_data.repo !== undefined) {
      lys.ws.send('sub repos ' + lys.page_data.repo);
    }
  };
  lys.ws.onclose   = function()  { console.log('websocket closed, reconnecting in 3s'); lys.initialized = false; setTimeout(lys.setupWs, 3000); };
  lys.ws.onmessage = function(m) { lys.handle(JSON.parse(m.data)); };
};

lys.repo_set = function(property, value) {
  console.log('setting property \'' + property + '\' to ' + value + ' for repo ' + lys.page_data.repo)
  lys.ws.send('repo_set ' + lys.page_data.repo + ' ' + property + ' ' + value);
};

window.addEventListener('load', function() {
  lys.setupWs();
});