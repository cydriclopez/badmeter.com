
$(function(){

    var cache = {};

    $( "#topic_title" )
    .bind('keypress', function(e) {
        if(e.keyCode==13){
            $( "#topic_title" ).autocomplete( "close" );
        }
    })
    .autocomplete({
        minLength: 3,
        source: function( request, response ){
            var term = request.term.trim();
            if ( term in cache ) {
                response( cache[ term ] );
                return;
            }
            $.getJSON( "/search/", request, function( data, status, xhr ){
                cache[ term ] = data;
                response( data );
            });
        },
        select: function( event, ui ) {
            $("#topic_title").val(ui.item.value.trim());
            $("#topic_title_form").submit()
        },
        open: function(event, ui) {
            $(this).autocomplete("widget").css({
                "width": "450",
                "font-size": "12px",
                "overflow": "hidden"
            });
        }
    });

    if ($(".messages li").size() > 0){
      $( ".messages" ).dialog({
        title: "Message",
        height: 250,
        width: 450,
        modal: true,
        buttons: {
          Close: function() {
            $( this ).dialog( "close" );
          }
        }
      });
    }

    $("#topic_title_form").submit(function(){
        return (slugify($("#topic_title").val())!="-");
    });

    $(".vote_negative").click(function(){
        $("#vote").val("false");
        $(".add_vote_form").submit()
    });
    $(".vote_positive").click(function(){
        $("#vote").val("true");
        $(".add_vote_form").submit()
    });
    $(".vote_cancel").click(function(){
        $("#vote").val("");
        $(".add_vote_comment_text").val("")
    });

    $(".new_topic_cancel_button").click(function(){
        window.location.href = "/index#home_section";
    });

});

function slugify(topic_title){
    return topic_title
        .toLowerCase()
        .replace(/[^0-9a-z]+/g,' ')
        .replace(/[ ]+/g,'-');
}