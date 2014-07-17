function renderAfishaEvents(events, rows_limit) {
    var i = 0;
    var j = 0;
    var row = 0;
    var html = '';

    $.each(events, function(j, e) {
        i++;
        row++;
        
        var size = 3;
        if ( (i == 1 || i == 2) && e.catalog_rate >= 4) {
            size = 6; 
            i++;
            row++;
        }

        if (typeof rows_limit != 'undefined' && row > rows_limit) {
            if (is_mobile == 0) { 
                $('#general_events_list').append('<div class="section group">'+html+'</div>');
            } else {
                $('#general_events_list').append(html);
            }

            return false
        }

        events_offset++;
        html += renderEvent(e, size);

        if (i == 3 || (j + 1) == events.length) {
            i = 0;

            if (is_mobile == 0) {
                $('#general_events_list').append('<div class="section group">'+html+'</div>');
            } else {
                $('#general_events_list').append(html);
            }

            html = '';
        }
    });
}

function renderMobileEvent(event, size) {
    // Prepare Image
    var image = '';
    var image_path = util.uploads_catalog;
    
    if (size == 3) {
        image = image_path + '/small_' + event.internal_id + '.jpg'; 
    } else if (size == 6) {
        image = image_path + '/medium_' + event.internal_id + '.jpg'; 
    }

    // Date prepare 
    var dt = event.start_short;

    // Tags prepare
    var tags = '';
    var tags_list = event.tags_short;

    $.each(tags_list, function(k, t) {
        var is_selected = '';
        if (tags_name_selected[t] == 1) {
            is_selected = 'class="highlight"';
        }

        tags += '<li '+is_selected+'>' + t + '</li> \
        ';
    });
    
    var hide = '';
    if (user_id) {
        var like_class, dislike_class; 

        if (likes[event.id] == 2) {
            hide = 'hidden';
        }
    }

    // Make html
    html = '<a id="event_'+event.id+'" href="'+event.link+'" class="container event-container '+hide+'" style="background-image: url(' + image + ')">'+
    '<div id="event-content_'+event.id+'" class="content"><div class="head"><h3>'+event.name+'</h3>'+
    '</div><div class="additional">' +
    '<div class="date-time left">' + dt + '</div>' +
    '<ul class="tags right">' + tags + '</ul>' +
    '</div></div></a> \
    ';

    return html;
}

function renderWebEvent(event, size) {

    // Prepare Image
    var image = '';
    var image_path = util.uploads_catalog;
    
    if (size == 3) {
        image = image_path + '/small_' + event.internal_id + '.jpg'; 
    } else if (size == 6) {
        image = image_path + '/medium_' + event.internal_id + '.jpg'; 
    }

    // Date prepare 
    var dt = '';

    if (size == 3) {
        dt = event.start_short;
    } else if (size == 6) {
        dt = event.start_full;
    }

    // Tags prepare
    var tags = '';
    var tags_list = [ ];
    if (size == 3) {
        tags_list = event.tags_short;
    } else if (size == 6) {
        tags_list = event.tags_full;
    }

    $.each(tags_list, function(k, t) {
        var is_selected = '';
        if (tags_name_selected[t] == 1) {
            is_selected = 'class="highlight"';
        }

        tags += '<li '+is_selected+'>' + t + '</li> \
        ';
    });
    
    var like_section = '';
    var show_likes = '';
    var hide = '';

    if (user_id) {
        var like_class, dislike_class; 

        if (likes[event.id] == 1) {
            like_class = 'like-active-icon';
            show_likes = 'likes-show';
        } else {
            like_class = 'like-icon';
        }

        if (likes[event.id] == 2) {
            dislike_class = 'dislike-active-icon';
            show_likes = 'likes-show';
            hide = 'hidden';
        } else {
            dislike_class = 'dislike-icon';
        }

        like_section = 
        '<div class="event-likes">' +
            '<span id="like_'+event.id+'" href="#" onclick="likeAfisha('+event.id+'); return false;" class="icon-30 '+like_class+'"></span>' +    
            '<span id="dislike_'+event.id+'" href="#" onclick="dislikeAfisha('+event.id+'); return false;" class="icon-30 '+dislike_class+'"></span>' +    
        '</div>';
    }

    // Make html
    html = '<a id="event_'+event.id+'" href="'+event.link+'" class="col span_'+size+'_of_12 event-block '+hide+'" style="background-image: url(' + image + ')">'+
    //'<div class="event-content"><h3>'+event.name+'</h3>' +
    '<div id="event-content_'+event.id+'" class="event-content '+show_likes+'"><div class="head"><h3>'+event.name+'</h3>'+
    like_section +
    '</div><div class="additional">' +
    '<div class="date-time left">' + dt + '</div>' +
    '<ul class="tags right">' + tags + '</ul>' +
    '</div></div></a>';

    return html;

}

function renderEvent(event, size) {
    if (is_mobile) {
        return renderMobileEvent(event, size);
    } else {
        return renderWebEvent(event, size);
    }
}

function setTag(e) {
    events_offset = 0;
    var tag_name = $(e).text();

    dfd = $.Deferred();
    $.getJSON(util.api.set_tag, { 'tag': tag_name }, function(data) {
        if (data.action == 'set') {
            tags_name_selected[tag_name] = 1;
            $(e).addClass('selected');
            $('.' + tag_name.replace(' ', '+')).addClass('selected');
        } else {
            tags_name_selected[tag_name] = 0;
            $(e).removeClass('selected');
            $('.' + tag_name.replace(' ', '+')).removeClass('selected');
        }

        dfd.resolve();
    }.bind(e));

    return dfd.promise();
}

function unsetTags() {
    dfd = $.Deferred();
    $.getJSON(util.api.unset_tags, function(data) {
        tags_name_selected = { };
        
        $('.music-tag').each(function() {
            $(this).removeClass('selected');
        });

        dfd.resolve();
    });

    return dfd.promise();
}

function updatePeriod() {
    $(".time-interval").each(function(i, el) {
        $(el).removeClass('selected');

        if ($(el).attr('interval') == time_interval) {
            $(el).addClass('selected');
        }
    });
}

function setPeriod(e) {
    time_interval = $(e).attr('interval');
    
    updatePeriod();
}

function showLoginSignupWindow() {
    $.fancybox.open('#login-signup-window', {
        'autoScale': true,
        'autoDimensions': true,
        'closeBtn': false,
        'centerOnScroll': true, 
        'padding': 0, 
        'helpers': {
            'overlay': {
                'css': {
                    'background': 'rgba(0, 0, 0, 0.3)'
                }
            }
        }
    });
}

/* 
==============================================================================
                                  INDEX PAGE
==============================================================================
*/

function loadEvents() {
    $.getJSON(util.api.get_general_events, { 'offset': events_offset }, function(data) {
        renderGeneralEvents(data.grid, data.events);
    });
}

function renderGeneralEvents(grid, events) {
    if (typeof events == 'undefined' || events.length == 0) {
       $('#load_more').hide();  
    } else {
       $('#load_more').show();  
    }

    $.each(grid, function(i, row) {
        var html = '';
        if (is_mobile == 0) {
            html = '<div class="section group">';
        }
        
        $.each(row, function(j, e) {
            var event = events.shift();

            events_offset++;

            if (typeof event == 'undefined') {
                return false;
                $('#load_more').hide();  
                return false;
            }

            render = renderEvent(event, e);
            html += render;
        });

        if (is_mobile == 0) {
            html += '</div>';
        }

        $('#general_events_list').append(html);
    });
}


/* 
==============================================================================
                                  AFISHA PAGE
==============================================================================
*/

function getAfishaEvents() {
    $('#no-results').hide();

    $.getJSON(util.api.get_afisha_events, { 'interval': time_interval }, function(data) {
        if (data.events.length == 0) {
            $('#general_events_list').hide();   
            $('#no-results').fadeIn();
        } else {
            $('#general_events_list').show();   
            $('#general_events_list').html('');   
            renderAfishaEvents(data.events);
        }
    });
}

/* 
==============================================================================
                                  SEARCH PAGE
==============================================================================
*/

function getSearchResults(interval) {
    $('#no-results').hide();

    $.getJSON(util.api.get_search_results, { 'interval': time_interval, 'query': search_query, 'sort': search_sort }, function(data) {
        if (data.events.length == 0) {
            $('#general_events_list').hide();   
            $('#no-results').fadeIn();
        } else {
            $('#general_events_list').show();   
            $('#general_events_list').html('');   
            renderAfishaEvents(data.events);
        }
    });
}

/* 
==============================================================================
                                PERSONAL INDEX PAGE
==============================================================================
*/

function getPersonalAfisha(clean) {
    processing = true; 

    $.getJSON(util.api.get_personal_afisha_events, { 'offset': events_offset, 'limit': 21, 'interval': time_interval }, function(data) {
        if (data.done == 1) {
            if (data.events.length > 0) {
                $('#general_events_list').show();   
                if (typeof clean != 'undefined') {
                    $('#general_events_list').html('');   
                }

                renderAfishaEvents(data.events, 21);
            } else {
                if (events_offset == 0) {
                    $('#general_events_list').html('');   
                    $('#general_events_list').hide();   
                    $('#no-results').fadeIn();
                }

                $(document).unbind('scroll');
            }
        }

        processing = false; 
    });
}

function showPersonalAfisha(set_interval) {
    console.log(is_sync_now);

    if (is_sync_now == 1) {
        return;
    }

    events_offset = 0; 

    $('#no-results').hide();
    $('#first-time').hide();
    $('#personal-head').show();

    $(document).scroll(function(e){
        if (processing) {
            return false;
        }

        if ($(window).scrollTop() >= ($(document).height() - $(window).height()) * 0.7){
            getPersonalAfisha();
        }
    });

    getPersonalAfisha('clean');
}

function checkSyncStatus() {
    $("#first-time").show();

    $.getJSON(util.api.get_sync_status, function(data) {
        if (typeof data.error == 'undefined') {
            var sync_status = data.done;
            var add = data.additional;

            if (sync_status == 1) {
                is_sync_now = 0;
                $('#sync-status').text('Синхронизация завершена!');
                clearTimeout(check_status_timer);
                showPersonalAfisha();

            } else if (sync_status == -1) {
                $('#sync-status').text('Ошибка синхронизации! Попробуйте позднее');
                clearTimeout(check_status_timer);

            } else {
                if (sync_status == 0) {
                    $('#sync-status').text('Ждем начала синхронизации...');
                } else if (sync_status == 2) {
                    $('#sync-status').text('Получаем данные из социальной сети...');
                } else if (sync_status == 3) {
                    $('#sync-status').text('Синхронизируем музыку...');
                } else if (sync_status == 4) {
                    $('#sync-status').text('Анализируем музыку...');
                }

                if (typeof add != 'undefined') {
                    if (sync_status == 4 && add.untagged > 0) {
                        $('#sync-status').text(
                            'Анализируем музыку... ('+ add.processed + '/' + add.untagged + ')');
                    } 
                }

                check_status_timer = setTimeout('checkSyncStatus()', 1000);
            }
        }
    });
}

/* 
==============================================================================
                                  EVENT PAGE
==============================================================================
*/

function like(id) {
    if (user_id) {
        $.getJSON(util.api.like, { 'id': id, 'type': 'like' }, function(data) {
            if (data.action == 'set') {
                $(".like").removeClass('like-icon');
                $(".like").addClass('like-active-icon');

                $(".dislike").removeClass('dislike-active-icon');
                $(".dislike").addClass('dislike-icon');
            } else {
                $(".like").addClass('like-icon');
                $(".like").removeClass('like-active-icon');
            }
        });
    } else {
        showLoginSignupWindow();
    }
}

function dislike(id) {
    if (user_id) {
        $.getJSON(util.api.like, { 'id': id, 'type': 'dislike' }, function(data) {
            if (data.action == 'set') {
                $(".dislike").removeClass('dislike-icon');
                $(".dislike").addClass('dislike-active-icon');

                $(".like").removeClass('like-active-icon');
                $(".like").addClass('like-icon');
            } else {
                $(".dislike").addClass('dislike-icon');
                $(".dislike").removeClass('dislike-active-icon');
            }
        });
    } else {
        showLoginSignupWindow();
    }
}

function likeAfisha(id) {
    if (user_id) {
        $.getJSON(util.api.like, { 'id': id, 'type': 'like' }, function(data) {
            if (data.action == 'set') {
                $("#like_"+id).removeClass('like-icon');
                $("#like_"+id).addClass('like-active-icon');

                $("#dislike_"+id).removeClass('dislike-active-icon');
                $("#dislike_"+id).addClass('dislike-icon');

                $("#event-content_"+id).addClass('likes-show');
                $("#event_"+id).removeClass('hidden');

                likes[id] = 1;
            } else {
                $("#like_"+id).addClass('like-icon');
                $("#like_"+id).removeClass('like-active-icon');

                $("#event-content_"+id).removeClass('likes-show');

                delete likes[id];
            }
        });
    } else {
        showLoginSignupWindow();
    }
}


function dislikeAfisha(id) {
    if (user_id) {
        $.getJSON(util.api.like, { 'id': id, 'type': 'dislike' }, function(data) {
            if (data.action == 'set') {
                $("#dislike_"+id).removeClass('dislike-icon');
                $("#dislike_"+id).addClass('dislike-active-icon');

                $("#like_"+id).removeClass('like-active-icon');
                $("#like_"+id).addClass('like-icon');

                $("#event-content_"+id).addClass('likes-show');
                $("#event_"+id).addClass('hidden');

                likes[id] = 2;
            } else {
                $("#dislike_"+id).addClass('dislike-icon');
                $("#dislike_"+id).removeClass('dislike-active-icon');

                $("#event-content_"+id).removeClass('likes-show');
                $("#event_"+id).removeClass('hidden');

                delete likes[id];
            }
        });
    } else {
        showLoginSignupWindow();
    }
}

function submitUserEmail() {
    var email = $('#user-email').val();

    var re = new RegExp(/([\w-\.]+)@((?:[\w]+\.)+)([a-zA-Z]{2,4})/i);
    var valid = re.test(email);

    if(!valid) {
        $('#user-email').addClass('input-error')
    } else {
        $.post(util.api.update_email, { 'email': email }, function( data ) {
        }, "json");

        $.fancybox.close();
    }
}

function showSubscribeWindow() {
    $.fancybox.open('#subscribe-window', {
        'autoScale': true,
        'autoDimensions': true,
        'closeBtn': false,
        'centerOnScroll': true, 
        'padding': 0, 
        'helpers': {
            'overlay': {
                'css': {
                    'background': 'rgba(0, 0, 0, 0.3)'
                }
            }
        }
    });
}

function submitUserSettings() {
    var email = $('#user-email').val();

    var re = new RegExp(/([\w-\.]+)@((?:[\w]+\.)+)([a-zA-Z]{2,4})/i);
    var valid = re.test(email);

    var subscribe = 0;
    if ($('#subscribe-on').prop('checked')) {
        subscribe = 1; 
    }

    if(!valid) {
        $('#user-email').addClass('input-error')
    } else {
        $.post(util.api.update_settings, { 'email': email, 'subscribe': subscribe }, function( data ) {
        }, "json");

        $.fancybox.close();
    }
}

/* 
==============================================================================
                                  MOBILE
==============================================================================
*/


function showPopularTagsWindow() {
    $.fancybox.open('#popular-tags-window', {
        'autoScale': true,
        'autoDimensions': true,
        'closeBtn': false,
        'centerOnScroll': true, 
        'padding': 0, 
        'helpers': {
            'overlay': {
                'css': {
                    'background': 'rgba(0, 0, 0, 0.3)'
                }
            }
        }
    });
}

function showTimeWindow() {
    $.fancybox.open('#time-window', {
        'autoScale': true,
        'autoDimensions': true,
        'closeBtn': false,
        'centerOnScroll': true, 
        'padding': 0, 
        'helpers': {
            'overlay': {
                'css': {
                    'background': 'rgba(0, 0, 0, 0.3)'
                }
            }
        }
    });
}

function showMyTagsWindow() {
    $.fancybox.open('#my-tags-window', {
        'autoScale': true,
        'autoDimensions': true,
        'closeBtn': false,
        'centerOnScroll': true, 
        'padding': 0, 
        'helpers': {
            'overlay': {
                'css': {
                    'background': 'rgba(0, 0, 0, 0.3)'
                }
            }
        }
    });
}
