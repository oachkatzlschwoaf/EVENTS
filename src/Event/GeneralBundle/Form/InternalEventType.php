<?php

namespace Event\GeneralBundle\Form;

use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\FormBuilderInterface;
use Symfony\Component\OptionsResolver\OptionsResolverInterface;

class InternalEventType extends AbstractType
{
        /**
     * @param FormBuilderInterface $builder
     * @param array $options
     */
    public function buildForm(FormBuilderInterface $builder, array $options)
    {
        $builder
            ->add('name')
            ->add('urlName')
            ->add('date')
            ->add('start')
            ->add('duration')
            ->add('description')
            ->add('video')
            ->add('catalogRate', 'choice', array(
                'choices' => array(
                    1 => 1,
                    2 => 2,
                    3 => 3,
                    4 => 4,
                    5 => 5
            )))
            ->add('tags', 'hidden')
            ->add('status', 'hidden')
            ->add('theme', 'choice', array(
                'choices' => array(
                    0  => 'black',
                    1  => 'white',
            )))
            ->add('bigTheme', 'choice', array(
                'choices' => array(
                    0  => 'black',
                    1  => 'white',
            )))
            ->add('style', 'choice', array(
                'choices' => array(
                    0  => 'head',
                    1  => 'medium pic',
                    2  => 'big pic',
            )))
        ;
    }
    
    /**
     * @param OptionsResolverInterface $resolver
     */
    public function setDefaultOptions(OptionsResolverInterface $resolver)
    {
        $resolver->setDefaults(array(
            'data_class' => 'Event\GeneralBundle\Entity\InternalEvent'
        ));
    }

    /**
     * @return string
     */
    public function getName()
    {
        return 'event_generalbundle_internalevent';
    }
}
