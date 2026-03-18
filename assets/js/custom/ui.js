(function () {

  /* ///////////////////////////////////////////////////////
   Ani.js
  */////////////////////////////////////////////////////////
  document.addEventListener("DOMContentLoaded", function () {
    AOS.init({
      delay: 0,
      offset: 60,
      once: true,
      duration: 1000, // 모든 AOS 애니메이션의 지속 시간을 1초(1000밀리초)로 설정
      disable: function () {
        // 화면 너비가 768픽셀 이하이면 AOS를 비활성화
        return window.innerWidth < 768;
      }
    });
  });


  /* ///////////////////////////////////////////////////////
   체험단 상세 슬라이드
  */////////////////////////////////////////////////////////

  const $testerSlide = document.querySelector('#tester-swiper');
  if ($testerSlide) {
    const testerSwiperThumbs = new Swiper('#tester-swiper-thumbs', {
      spaceBetween: 10,
      slidesPerView: 5,
      freeMode: true,
      watchSlidesProgress: true,
    });
    const testerSwiper = new Swiper('#tester-swiper', {
      loop: true,
      thumbs: {
        swiper: testerSwiperThumbs,
      },
      navigation: {
        nextEl: ".swiper-button-next",
        prevEl: ".swiper-button-prev",
      },
    });
  }

  $(document).on("click", ".review .add-more-btn", function(e) {
    e.preventDefault();

    var _this =$(this),
    cur_page = _this.attr("data-cur_page"),
    data_obj = JSON.parse(_this.attr("data-var_json")),
    //add_more_wrapper = _this.closest(".review").find(".add_more_wrapper:first");
    add_more_wrapper = _this.siblings(".add_more_wrapper:first");

    //console.log(data_obj, add_more_wrapper.length);

    if (!add_more_wrapper.length || !cur_page || !data_obj || !data_obj.total_page) return false;

    if (cur_page >= data_obj.total_page) {
      return false;
    }

    data_obj.cur_page = cur_page;

    $.ajax({
      url : g5_shop_url + "/ajax.review.php",
      contentType: "application/x-www-form-urlencoded;charset=utf-8",
      data: data_obj,
      type: 'POST',
      datatype: 'JSON',
      success: function (result) {
        //console.log(result);
        if (result.error || !result.data || !result.page) {
          return false;
        }

        var scroll_top = document.documentElement.scrollTop,
        wrapper_height = add_more_wrapper.height();

        add_more_wrapper.append(result.data);

        setTimeout(function() {
          if (result.data.indexOf("data-aos=" != -1)) {
            AOS.init({
              disable: function () {
                return true;
              }
            });
          }
          var height_add = add_more_wrapper.height() - wrapper_height;
          if (height_add > 0) {
            $('html, body').animate({ scrollTop: scroll_top + height_add }, 300);
          }
        }, 300);

        _this.attr("data-cur_page", result.page);
        if (data_obj.total_page == result.page) {
          _this.remove().end();
        }
      },
      error: function (request, status, error) {
        //console.log(result);
      }
    });
  });

})();